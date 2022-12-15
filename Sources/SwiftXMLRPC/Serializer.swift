import Foundation

public protocol XMLSerializable {
    func asString() -> String
    func asData() -> Data
}

public extension XMLSerializable {
    func asData() -> Data {
        Data(asString().utf8)
    }
}

public extension XMLRPC.Call {
    func asString() -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodCall><methodName>\(method)</methodName><params><param>\(param.asString())</param></params></methodCall>"
    }
}

public extension XMLRPC.Response {
    func asString() -> String {
        let body: String
        switch self {
        case let .fault(code, description):
            let fault = XMLRPC.Parameter.struct(
                [
                    "faultCode": .int(code),
                    "faultString": .string(description)
                ]
            )
            body = "<fault>\(fault.asString())</fault>"
        case let .param(param):
            body = "<params><param>\(param.asString())</param></params>"
        }

        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodResponse>\(body)</methodResponse>"
    }
}

extension XMLRPC.Parameter {
    var valueName: String {
        switch self {
        case .string:
            return "string"
        case .array:
            return "array"
        case .struct:
            return "struct"
        case .data:
            return "base64"
        case .date:
            return "dateTime.iso8601"
        case .bool:
            return "boolean"
        case .int:
            return "int"
        case .double:
            return "double"
        }
    }

    var value: String {
        let name = valueName
        return "<value><\(name)>\(contents)</\(name)></value>"
    }

    var contents: String {
        switch self {
        case let .string(value):
            return value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
        case let .array(contents):
            return "<data>\(contents.map(\.value).joined())</data>"
        case let .struct(contents):
            return contents
                .map { "<member><name>\(Self.string($0).contents)</name>\($1.value)</member>" }
                .joined()
        case let .data(value):
            return value.base64EncodedString()
        case let .date(value):
            return xmlDateFormatter.string(from: value)
        case let .bool(value):
            return (value ? 1 : 0).description
        case let .int(value):
            return value.description
        case let .double(value):
            return value.description
        }
    }

    public func asString() -> String {
        value
    }
}