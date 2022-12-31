import Foundation
import SwiftParsec

extension XMLRPC.Parameter {
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

    static let base64ValidCharacters = {
        CharacterSet(charactersIn: "A"..."Z")
            .union(.init(charactersIn: "a"..."z"))
            .union(.init(charactersIn: "0"..."9"))
            .union(.init(charactersIn: "+/=\r\n"))
    }()

    static let parser: GenericParser<String, (), Self> = {
        let char = StringParser.character
        let string = StringParser.string
        let spaces = StringParser.spaces
        let noneOf = StringParser.noneOf
        let letter = StringParser.letter
        let digit = StringParser.digit
        let plusOrMinus = StringParser.oneOf("+-")
            .stringValue
            .optional
            .map { $0.map { String($0) } ?? "" }

        let xmlString = string("string").xmlTag(
            body: Self.string <^> .unquotedXMLString
        )
        let xmlBool = Self.bool <^> string("boolean").xmlTag(
            body: (spaces *> (char("1") <|> char("0")) <* spaces).map {
                $0 == "1"
            }
        )
        let intParser = plusOrMinus >>- { sign in
            digit.many1.stringValue.map { real in
                "\(sign)\(real)"
            }
        }
        let xmlNil = spaces *> (string("<") *> spaces *> string("nil") <* spaces <* string("/>"))
            .map { _ in
                Self.nil
            }
        let xmlInt = string("i") >>- { _ in
            string("nt") <|> string("1") <|> string("2") <|> string("4") <|> string("1")
        }
        let xmlInt8 = string("i1").xmlTag(
            body: (spaces *> intParser <* spaces)
        ) >>- {
            Int8($0)
                .map { GenericParser.init(result: Self.int8($0)) }
            ?? .fail("invalid int8")
        }
        let xmlInt16 = string("i2").xmlTag(
            body: (spaces *> intParser <* spaces)
        ) >>- {
            Int16($0)
                .map { GenericParser.init(result: Self.int16($0)) }
            ?? .fail("invalid int16")
        }
        let xmlInt32 = (string("i4").attempt <|> string("int")).xmlTag(
            body: (spaces *> intParser <* spaces)
        ) >>- {
            Int32($0)
                .map { GenericParser.init(result: Self.int32($0)) }
            ?? .fail("invalid int32")
        }
        let xmlInt64 = string("i8").xmlTag(
            body: (spaces *> intParser <* spaces)
        ) >>- {
            Int64($0)
                .map { GenericParser.init(result: Self.int64($0)) }
            ?? .fail("invalid int64")
        }
        let doubleParser = plusOrMinus >>- { sign in
            digit.many1.stringValue >>- { real in
                (char(".") *> digit.many1.stringValue) >>- { fraction in
                    Double("\(sign)\(real).\(fraction)").map {
                        .init(result: $0)
                    }
                    ?? .fail("invalid double")
                }
            }
        }
        let xmlDouble = Self.double <^> string("double").xmlTag(
            body: spaces *> doubleParser <* spaces
        )
        let dateParser = digit.count(8).stringValue >>- { date in
            char("T") *> digit.count(2).stringValue <* char(":") >>- { hour in
                digit.count(2).stringValue <* char(":") >>- { minute in
                    digit.count(2).stringValue >>- { second in
                        xmlDateFormatter
                            .date(from: "\(date)T\(hour):\(minute):\(second)")
                            .map {
                                GenericParser(
                                    result: Self.date($0)
                                )
                            }
                        ?? .fail("invalid iso8601 date")
                    }
                }
            }
        }
        let xmlDate = string("dateTime.iso8601").xmlTag(
            body: spaces *> dateParser <* spaces
        )
        let dataParser = StringParser.satisfy {
            $0.unicodeScalars.allSatisfy(
                Self.base64ValidCharacters.contains
            )
        }.many.stringValue >>- { base64 -> GenericParser<String, (), XMLRPC.Parameter> in
            Data(
                base64Encoded: base64 + String(
                    repeating: "=",
                    count: 4 - base64.count % 4
                )
            ).map {
                .init(result: Self.data($0))
            } ?? .fail("invalid base64")
        }
        let xmlData = string("base64").xmlTag(
            body: spaces *> dataParser <* spaces
        )

        return .recursive { param in
            let xmlArray = string("array").xmlTag(
                body: string("data").xmlTag(
                    body: Self.array <^> param.manyTill(
                        (
                            spaces
                            *> string("</")
                            *> spaces
                            *> string("data")
                            *> spaces
                            *> char(">")
                        ).attempt.lookAhead
                    )
                )
            )
            let xmlStruct = string("struct").xmlTag(
                body: string("member").xmlTag(
                    body: string("name").xmlTag(
                        body: .unquotedXMLString
                    )
                    .flatMap { name in
                        param.map {
                            (name, $0)
                        }
                    }
                )
                .manyTill(
                    (
                        spaces
                        *> string("</")
                        *> spaces
                        *> string("struct")
                        *> spaces
                        *> char(">")
                    ).attempt.lookAhead
                )
                .map {
                    Self.struct(.init($0, uniquingKeysWith: { $1 }))
                }
            )

            return string("value").xmlTag(
                body: [
                    xmlNil,
                    xmlBool,
                    xmlInt8,
                    xmlInt16,
                    xmlInt32,
                    xmlInt64,
                    xmlDouble,
                    xmlData,
                    xmlDate,
                    xmlArray,
                    xmlStruct,
                ].reduce(xmlString.attempt) { $0 <|> $1.attempt }
            )
        }
    }()
}
