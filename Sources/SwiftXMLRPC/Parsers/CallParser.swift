import Foundation
import SwiftParsec

extension XMLRPC.Call {
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

    static let methodValidCharacters = {
        CharacterSet(charactersIn: "A"..."Z")
            .union(.init(charactersIn: "a"..."z"))
            .union(.init(charactersIn: "0"..."9"))
            .union(.init(charactersIn: "_.:/"))
    }()

    static let parser: GenericParser<String, (), Self> = {
        let char = StringParser.character
        let string = StringParser.string
        let spaces = StringParser.spaces
        let noneOf = StringParser.noneOf

        let xmlDecl = string("<?xml") *> noneOf("?>").many.stringValue <* string("?>")

        let methodNameParser = StringParser.satisfy {
            $0.unicodeScalars.allSatisfy(
                Self.methodValidCharacters.contains
            )
        }.many1.stringValue
        
        let params = string("params").xmlTag(
            body: string("param").xmlTag(
                body: XMLRPC.Parameter.parser
            )
            .many1Till(
                (
                    string("</")
                    *> spaces
                    *> string("params")
                    *> spaces
                    *> char(">")
                ).attempt.lookAhead
            )
        )

        return spaces *> xmlDecl.attempt *> string("methodCall").xmlTag(
            body: string("methodName").xmlTag(
                body: methodNameParser
            ) >>- { method in
                (spaces *> params <* spaces).map { params in
                    Self(method: method, params: params)
                }
            }
        )
    }()
}
