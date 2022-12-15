import XCTest
import SwiftXMLRPC
import SwiftCheck

extension Gen where A: Sequence, A.Element == UnicodeScalar {
    var string: Gen<String> {
        return map { String($0.map(Character.init)) }
    }
}

extension UnicodeScalar {
    static func allScalars(from first: UnicodeScalar, upTo last: Unicode.Scalar) -> [UnicodeScalar] {
        return Array(first.value ..< last.value).compactMap(UnicodeScalar.init)
    }
    
    static func allScalars(from first: UnicodeScalar, through last: UnicodeScalar) -> [UnicodeScalar] {
        return allScalars(from: first, upTo: last) + [last]
    }
}

let integers = Gen.one(of: [
    .zipWith(
        Gen.fromElements(of: UnicodeScalar.allScalars(from: "1", through: "9")).map { String(Character($0)) },
        .frequency([(3, allNumbers), (1, .pure(""))]),
        transform: +
    ),
    .pure("0")
])

let allNumbers = UnicodeScalar.arbitrary.suchThat(CharacterSet(charactersIn: "0"..."9").contains).proliferate.string

enum XMLRPCTestParameter {
    case int(String)
    case bool(String)
    case string(String)
    case double(String)
    case date(String)
    case data(String)
    indirect case `struct`([String: Self])
    indirect case array([Self])

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
        case let .array(contents):
            return "<data>\(contents.map(\.value).joined())</data>"
        case let .struct(contents):
            return contents
                .map { "<member><name>\($0)</name>\($1.value)</member>" }
                .joined()
        case let .data(value):
            return value
        case let .date(value):
            return value
        case let .bool(value):
            return value
        case let .int(value):
            return value
        case let .double(value):
            return value
        }
    }

    public func serialize() -> String {
        value
    }
}

extension Date: Arbitrary {
    public static var arbitrary: Gen<Date> {
        Double.arbitrary.map(Date.init(timeIntervalSince1970:))
    }
}

extension String {
    public static var arbitraryXMLString: Gen<String> {
        String.arbitrary.map { string in
            string
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
        }
        .ap(
            .fromElements(
                of: [
                    (">", "&gt;"),
                    ("'", "&apos;"),
                    ("\"","&quot;")
                ]
                .map { (char, repl) in
                    { $0.replacingOccurrences(of: char, with: repl) }
                }
            )
        )
    }
}

extension XMLRPC.Parameter: Arbitrary {
    public static var nonRecursives: [Gen<Self>] {
        [
            Int.arbitrary.map { .int($0) },
            Date.arbitrary.map { .date($0) },
            Double.arbitrary.map { .double($0) },
            String.arbitrary.map { .string($0) },
            [UInt8].arbitrary.map { .data(Data($0)) },
            Bool.arbitrary.map { .bool($0) }
        ]
    }

    public static func arbitary(maxRecursionDepth maxDepth: Int, currentDepth: Int = 0) -> Gen<Self> {
        .one(
            of: nonRecursives + (currentDepth < maxDepth ? [
                arbitary(maxRecursionDepth: maxDepth, currentDepth: currentDepth + 1)
                    .proliferate
                    .map { .array($0) },
                Gen.zip(String.arbitrary, arbitary(maxRecursionDepth: maxDepth, currentDepth: currentDepth + 1))
                    .proliferate
                    .map { .struct(Dictionary($0, uniquingKeysWith: { $1 })) }
            ] : [])
        )
    }

    public static var arbitrary: Gen<XMLRPC.Parameter> {
        arbitary(maxRecursionDepth: 1)
    }
}

extension XMLRPC.Response: Arbitrary {
    public static var arbitrary: Gen<Self> {
        .one(of: [
            XMLRPC.Parameter.arbitrary.proliferateNonEmpty.map(Self.params),
            Gen.zip(Int.arbitrary, String.arbitrary).map(Self.fault),
        ])
    }
}

extension XMLRPC.Call: Arbitrary {
    public static var arbitrary: Gen<Self> {
        Gen.zip(
            Gen.fromElements(
                of: UnicodeScalar.allScalars(from: "a", through: "z")
                + UnicodeScalar.allScalars(from: "A", through: "Z")
                + [".", "/", "_", ":"]
            ).proliferateNonEmpty.string,
            XMLRPC.Parameter.arbitrary.proliferateNonEmpty
        )
        .map(Self.init)
    }
}

let xmlDateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd'T'HH:mm:ss"
    return formatter
}()

final class SwiftXMLRPCTests: XCTestCase {
    func test() throws {
        func value(type: String, _ value: String) -> String {
            "<value><\(type)>\(value)</\(type)></value>"
        }

        property("Doubles") <- forAllNoShrink(
            Double.arbitrary.map(abs).flatMap { double in
                Gen<String>.fromElements(of: ["+", "-", ""]).map {
                    "\($0)\(double)"
                }
            }
        ) { double in
            switch XMLRPC.Parameter.deserialize(from: value(type: "double", double)) {
            case .success:
                return true
            case let .failure(error):
                print(error)
                return false
            }
        }

        property("Ints") <- forAllNoShrink(
            Int.arbitrary.map(abs).flatMap { int in
                Gen<String>.fromElements(of: ["+", "-", ""]).map {
                    "\($0)\(int)"
                }
            }
        ) { int in
            switch XMLRPC.Parameter.deserialize(from: value(type: "int", int)) {
            case .success:
                return true
            case let .failure(error):
                print(error)
                return false
            }
        }
        
        property("Dates") <- forAllNoShrink(Date.arbitrary) { date in
            switch XMLRPC.Parameter.deserialize(from: value(type: "dateTime.iso8601", xmlDateFormatter.string(from: date))) {
            case .success:
                return true
            case let .failure(error):
                print(error)
                return false
            }
        }
        
        property("Strings") <- forAllNoShrink(
            Gen.one(of: [
                Gen.fromElements(of: [
                    "lt",
                    "gt",
                    "quot",
                    "apos",
                    "amp",
                ])
                .map { "&\($0);" },
                String.arbitraryXMLString
            ])
            .proliferate
            .map { $0.joined() }
        ) { string in
            switch XMLRPC.Parameter.deserialize(from: value(type: "string", string)) {
            case let .success(.string(result)):
                return result == string
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&apos;", with: "'")
                    .replacingOccurrences(of: "&quot;", with: "\"")
            case let .failure(error):
                print(error)
                return false
            default:
                return false
            }
        }

        property("Round trip Call") <- forAllNoShrink(
            XMLRPC.Call.arbitrary
        ) { call in
            switch XMLRPC.Call.deserialize(from: call.serialize()) {
            case .success:
                return true
            case let .failure(error):
                print(call.serialize())
                print(error)
                return false
            }
        }

        property("Round trip Response") <- forAllNoShrink(
            XMLRPC.Response.arbitrary
        ) { response in
            switch XMLRPC.Response.deserialize(from: response.serialize()) {
            case .success:
                return true
            case let .failure(error):
                print(error)
                return false
            }
        }

        property("Round trip Parameter") <- forAllNoShrink(
            XMLRPC.Parameter.arbitary(maxRecursionDepth: 2)
        ) { xml in
            switch XMLRPC.Parameter.deserialize(from: xml.serialize()) {
            case .success:
                return true
            case let .failure(error):
                print(error)
                return false
            }
        }
    }
}
