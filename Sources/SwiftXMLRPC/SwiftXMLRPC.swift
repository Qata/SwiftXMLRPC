import Foundation

let xmlDateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd'T'HH:mm:ss"
    return formatter
}()

public enum XMLRPC {
}

public extension XMLRPC {
    struct Call: Hashable, Codable, XMLSerializable {
        public let method: String
        public let params: [XMLRPC.Parameter]
        
        public init(method: String, params: [XMLRPC.Parameter]) {
            self.method = method
            self.params = params
        }
    }

    enum Response: Hashable, Codable, XMLSerializable {
        case params([XMLRPC.Parameter])
        case fault(code: Int32, description: String)
    }

    indirect enum Parameter: Hashable, Codable, XMLSerializable {
        case `nil`
        case int8(Int8)
        case int16(Int16)
        case int32(Int32)
        case int64(Int64)
        case bool(Bool)
        case string(String)
        case double(Double)
        case date(Date)
        case data(Data)
        case `struct`([String: Self])
        case array([Self])
    }
}
