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
        public let param: XMLRPC.Parameter
        
        public init(method: String, param: XMLRPC.Parameter) {
            self.method = method
            self.param = param
        }
    }

    enum Response: Hashable, Codable, XMLSerializable {
        case param(XMLRPC.Parameter)
        case fault(code: Int, description: String)
    }

    indirect enum Parameter: Hashable, Codable, XMLSerializable {
        case int(Int)
        case bool(Bool)
        case string(String)
        case double(Double)
        case date(Date)
        case data(Data)
        case `struct`([String: Self])
        case array([Self])
    }
}
