import SwiftParsec

extension GenericParser {
    func many1Till<End>(
        _ end: GenericParser<StreamType, UserState, End>
    ) -> GenericParser<StreamType, UserState, [Result]> {
        func scan() -> GenericParser<StreamType, UserState, [Result]> {
            
            let empty = end *>
                GenericParser<StreamType, UserState, [Result]>(result: [])
            
            return empty <|> (self >>- { result in
                
                scan() >>- { results in
                    
                    let rs = results.prepending(result)
                    return GenericParser<StreamType, UserState, [Result]>(
                        result: rs
                    )
                    
                }
                
            })
            
        }

        return self >>- { first in
            scan().map {
                [first] + $0
            }
        }
    }
}

extension GenericParser where Result == String {
    func concat<Next: StringProtocol>(
        _ next: GenericParser<StreamType, UserState, Next>
    ) -> GenericParser<StreamType, UserState, Result> {
        self >>- { current in
            next.map {
                current + .init($0)
            }
        }
    }

    func concat<Next: StringProtocol>(
        _ next: GenericParser<StreamType, UserState, Next?>
    ) -> GenericParser<StreamType, UserState, Result> {
        self >>- { current in
            next.map {
                $0.map {
                    current + .init($0)
                } ?? current
            }
        }
    }

    func concat(
        _ next: GenericParser<StreamType, UserState, Character>
    ) -> GenericParser<StreamType, UserState, Result> {
        self >>- { current in
            next.map {
                current + .init($0)
            }
        }
    }

    func concat(
        _ next: GenericParser<StreamType, UserState, Character?>
    ) -> GenericParser<StreamType, UserState, Result> {
        self >>- { current in
            next.map {
                $0.map {
                    current + .init($0)
                } ?? current
            }
        }
    }

    func concat(
        _ next: GenericParser<StreamType, UserState, [Character]>
    ) -> GenericParser<StreamType, UserState, Result> {
        self >>- { current in
            next.map {
                current + .init($0)
            }
        }
    }

    func concat(
        _ next: GenericParser<StreamType, UserState, [Character]?>
    ) -> GenericParser<StreamType, UserState, Result> {
        self >>- { current in
            next.map {
                $0.map {
                    current + .init($0)
                } ?? current
            }
        }
    }
}

extension GenericParser where Result == String {
    static var unquotedXMLString: GenericParser<String, (), Result> {
        (
            (
                StringParser.string("&")
                *> StringParser.noneOf(";").many1.stringValue
                <* StringParser.character(";") >>- { escaped in
                    switch escaped {
                    case "quot":
                        return .init(result: "\"")
                    case "apos":
                        return .init(result: "'")
                    case "lt":
                        return .init(result: "<")
                    case "gt":
                        return .init(result: ">")
                    case "amp":
                        return .init(result: "&")
                    default:
                        return .fail("invalid escape character")
                    }
                }
            ) <|> StringParser.noneOf("<")
        )
        .many.stringValue
    }
}

extension GenericParser
where StreamType == String, UserState == (), Result == String {
    func tag(closing: Bool) -> GenericParser<String, (), Result> {
        let string = StringParser.string
        let char = StringParser.character
        let spaces = StringParser.spaces
        return spaces
        *> char("<")
        *> string(closing ? "/" : "")
        *> spaces
        *> self
        <* spaces
        <* char(">")
    }

    var openingTag: GenericParser<String, (), Result> {
        tag(closing: false)
    }

    var closingTag: GenericParser<String, (), Result> {
        tag(closing: true)
    }

    func xmlTag<Result>(
        body: GenericParser<String, (), Result>
    ) -> GenericParser<String, (), Result> {
        openingTag *> body <* closingTag
    }
}
