import XCTest
import SwiftXMLRPC
import SwiftCheck

extension Gen where A: Sequence, A.Element == UnicodeScalar {
    var string: Gen<String> {
        return map { String($0.map(Character.init)) }
    }
}

extension Gen {
    var optional: Gen<A?> {
        flatMap { .fromElements(of: [nil, $0]) }
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
    case `nil`
    case int8(String)
    case int16(String)
    case int32(String)
    case int64(String)
    case bool(String)
    case string(String)
    case double(String)
    case date(String)
    case data(String)
    indirect case `struct`([String: Self])
    indirect case array([Self])

    var valueName: String {
        switch self {
        case .nil:
            fatalError()
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
        case .int8:
            return "i1"
        case .int16:
            return "i2"
        case .int32:
            return "i4"
        case .int64:
            return "i8"
        case .double:
            return "double"
        }
    }

    func value(spaces: Gen<String>) -> Gen<String> {
        switch self {
        case .nil:
            return .zipWith(spaces.proliferate(withSize: 4), contents(spaces: spaces)) {
                "\($0[0])<value>\($0[1])\($1)\($0[2])</value>\($0[3])"
            }
        default:
            return .zipWith(spaces.proliferate(withSize: 4), .pure(valueName), contents(spaces: spaces)) {
                "\($0[0])<value>\($0[1])<\($1)>\($2)</\($1)>\($0[2])</value>\($0[3])"
            }
        }
    }

    func contents(spaces: Gen<String>) -> Gen<String> {
        switch self {
        case .nil:
            return .pure("<nil/>")
        case let .string(value):
            return .pure(value)
        case let .array(contents):
            return .zipWith(
                spaces.proliferate(withSize: 4),
                sequence(contents.map { $0.value(spaces: spaces) }).map { $0.joined() }
            ) {
                "\($0[0])<data>\($0[1])\($1)\($0[2])</data>\($0[3])"
            }
        case let .struct(contents):
            return spaces.proliferate(withSize: 3).flatMap { s in
                sequence(
                    contents.map { key, value in
                        value.value(spaces: spaces).map {
                            "\(s[0])<member>\(s[1])<name>\(key)</name>\($0)</member>\(s[2])"
                        }
                    }
                ).map { $0.joined() }
            }
        case let .data(value):
            return .pure(value)
        case let .date(value):
            return .pure(value)
        case let .bool(value):
            return .pure(value)
        case let .int8(value):
            return .pure(value)
        case let .int16(value):
            return .pure(value)
        case let .int32(value):
            return .pure(value)
        case let .int64(value):
            return .pure(value)
        case let .double(value):
            return .pure(value)
        }
    }

    public func serialize(spaces: Gen<String>) -> Gen<String> {
        value(spaces: spaces)
    }
}

extension XMLRPCTestParameter: Arbitrary {
    static var arbitrary: Gen<XMLRPCTestParameter> {
        XMLRPC.Parameter.arbitrary.map {
            func recurse(_ param: XMLRPC.Parameter) -> XMLRPCTestParameter {
                switch param {
                case .nil:
                    return .nil
                case let .string(value):
                    return .string(
                        value
                            .replacingOccurrences(of: "&", with: "&amp;")
                            .replacingOccurrences(of: "<", with: "&lt;")
                            .replacingOccurrences(of: ">", with: "&gt;")
                            .replacingOccurrences(of: "'", with: "&apos;")
                            .replacingOccurrences(of: "\"", with: "&quot;")
                    )
                case let .array(contents):
                    return .array(contents.map(recurse))
                case let .struct(contents):
                    return .struct(
                        .init(
                            contents.map { key, value in
                                (
                                    key
                                        .replacingOccurrences(of: "&", with: "&amp;")
                                        .replacingOccurrences(of: "<", with: "&lt;")
                                        .replacingOccurrences(of: ">", with: "&gt;")
                                        .replacingOccurrences(of: "'", with: "&apos;")
                                        .replacingOccurrences(of: "\"", with: "&quot;"),
                                    recurse(value)
                                )
                            },
                            uniquingKeysWith: { $1 }
                        )
                    )
                case let .data(value):
                    return .data(value.base64EncodedString())
                case let .date(value):
                    return .date(xmlDateFormatter.string(from: value))
                case let .bool(value):
                    return .bool(value ? "1" : "0")
                case let .int8(value):
                    return .int8(value.description)
                case let .int16(value):
                    return .int16(value.description)
                case let .int32(value):
                    return .int32(value.description)
                case let .int64(value):
                    return .int64(value.description)
                case let .double(value):
                    return .double(value.description)
                }
            }
            return recurse($0)
        }
    }
}

extension Date: Arbitrary {
    public static var arbitrary: Gen<Date> {
        Double.arbitrary.map(Date.init(timeIntervalSince1970:))
    }
}

extension String {
    private static var arbitraryXMLCharacter: Gen<Character> {
        Gen<UInt8>.choose((32, 126)).flatMap {
            .pure(.init(UnicodeScalar($0)))
        }
    }
    
    public static var arbitraryXMLStringTransforms: Gen<(String) -> String> {
        Gen.fromElements(
            of: [
                (">", "&gt;"),
                ("'", "&apos;"),
                ("\"","&quot;")
            ]
            .map { char, repl in
                { $0.replacingOccurrences(of: char, with: repl) }
            }
        )
        .proliferateNonEmpty
        .map {
            $0.dropFirst().reduce($0.first!) { partialResult, next in
                { next(partialResult($0)) }
            }
        }
    }

    public static var arbitraryXMLString: Gen<String> {
        Gen.sized(arbitraryXMLCharacter.proliferate(withSize:)).map {
            String($0)
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
        }
    }
}

extension XMLRPC.Parameter: Arbitrary {
    public static var nonRecursives: [Gen<Self>] {
        [
            Int8.arbitrary.map { .int8($0) },
            Int16.arbitrary.map { .int16($0) },
            Int32.arbitrary.map { .int32($0) },
            Int64.arbitrary.map { .int64($0) },
            Date.arbitrary.map { .date($0) },
            Double.arbitrary.map { .double($0) },
            String.arbitrary.map { .string($0) },
            [UInt8].arbitrary.map { .data(Data($0)) },
            Bool.arbitrary.map { .bool($0) },
            .pure(.nil)
        ]
    }

    public static func arbitrary(maxRecursionDepth maxDepth: Int, currentDepth: Int = 0) -> Gen<Self> {
        .one(
            of: nonRecursives + (currentDepth < maxDepth ? [
                arbitrary(maxRecursionDepth: maxDepth, currentDepth: currentDepth + 1)
                    .proliferate
                    .map { .array($0) },
                Gen.zip(String.arbitrary, arbitrary(maxRecursionDepth: maxDepth, currentDepth: currentDepth + 1))
                    .proliferate
                    .map { .struct(Dictionary($0, uniquingKeysWith: { $1 })) }
            ] : [])
        )
    }

    public static var arbitrary: Gen<XMLRPC.Parameter> {
        arbitrary(maxRecursionDepth: 1)
    }
}

extension XMLRPC.Response: Arbitrary {
    public static var arbitrary: Gen<Self> {
        .one(of: [
            XMLRPC.Parameter.arbitrary.proliferateNonEmpty.map(Self.params),
            Gen.zip(Int32.arbitrary, String.arbitrary).map(Self.fault),
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

let iso8601Variant = Gen.fromElements(of: ["-", ""]).flatMap { hyphen in
    Gen.fromElements(of: [
        ":",
//        ""
    ]).flatMap { colon in
        let timezone = Gen.one(of: [
            .pure("Z"),
            .zipWith(
                .fromElements(of: ["+", "-"]),
                .fromElements(of: ["", "00", ":00"])
            ) { sign, minute in
                "\(sign)00\(minute)"
            }
        ])
        let time = Gen.one(
            of: [
                timezone.map {
                    "T06\(colon)18\(colon)37\($0)"
                },
//                .pure("")
            ]
        )
        return time.map {
            "2023-01-02\($0)"
        }
    }
}

final class SwiftXMLRPCTests: XCTestCase {
    func test() throws {
        func value(type: String, _ value: String) -> String {
            "<value><\(type)>\(value)</\(type)></value>"
        }

        let randomlySpacedXML = XMLRPCTestParameter.arbitrary.flatMap {
            $0.value(
                spaces: Gen.fromElements(of: [" ", "\n", "\t"])
                    .proliferateNonEmpty
                    .map { $0.joined() }
            )
        }

        property("Random spacing is ignored", arguments: .init(replay: (StdGen(108627618, 9606), 0))) <- forAllNoShrink(randomlySpacedXML) {
            switch XMLRPC.Parameter.deserialize(from: $0) {
            case .success:
                return true
            case let .failure(error):
                print($0)
                print(error)
                return false
            }
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

        property("ISO8601 Dates") <- forAllNoShrink(iso8601Variant) { date in
            switch XMLRPC.Parameter.deserialize(from: value(type: "dateTime", date)) {
            case .success(.date):
                return true
            case let .failure(error):
                print(date)
                print(error)
                return true
            default:
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
        
        property("Nil") <- forAllNoShrink(.pure(XMLRPC.Parameter.nil)) {
            switch XMLRPC.Parameter.deserialize(from: $0.serialize()) {
            case let .success(result):
                return result == $0
            case let .failure(error):
                print(error)
                return false
            }
        }

        property("Strings") <- forAllNoShrink(
            String.arbitraryXMLString,
            String.arbitraryXMLStringTransforms
        ) { string, transform in
            switch XMLRPC.Parameter.deserialize(from: value(type: "string", transform(string))) {
            case let .success(result):
                return result.serialize() == value(type: "string", string)
            case let .failure(error):
                print(error)
                print(string)
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
            XMLRPC.Parameter.arbitrary(maxRecursionDepth: 2)
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
