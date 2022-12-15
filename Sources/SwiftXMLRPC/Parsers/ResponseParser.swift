import Foundation
import SwiftParsec

extension XMLRPC.Response {
    public static func deserialize(
        from input: String,
        sourceName: String? = nil
    ) -> Result<Self, ParsingError> {
        switch parser.runSafe(
            userState: (),
            sourceName: sourceName ?? "XMLRPC",
            input: input
        ) {
        case let .left(error):
            return .failure(.init(description: error.description))
        case let .right(value):
            return .success(value)
        }
    }

    static let parser: GenericParser<String, (), Self> = {
        let string = StringParser.string
        let spaces = StringParser.spaces
        let noneOf = StringParser.noneOf

        let xmlDecl = string("<?xml") *> noneOf("?>").many.stringValue <* string("?>")

        let params = Self.param <^> string("params").xmlTag(
            body: string("param").xmlTag(
                body: XMLRPC.Parameter.parser
            )
        )
        let fault = string("fault").xmlTag(
            body: XMLRPC.Parameter.parser >>- { fault in
                switch fault {
                case let .struct(values):
                    switch (values["faultCode"], values["faultString"]) {
                    case let (.int(code), .string(description)):
                        return .init(result: Self.fault(code: code, description: description))
                    default:
                        return .fail("invalid fault xml")
                    }
                default:
                    return .fail("invalid fault xml")
                }
            }
        )

        return spaces *> xmlDecl.attempt *> string("methodResponse").xmlTag(
            body: spaces *> (params.attempt <|> fault) <* spaces
        )
    }()
}
