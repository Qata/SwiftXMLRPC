import Foundation
import SwiftParsec

public struct ParsingError: Error, CustomStringConvertible {
    public let description: String
}

public protocol XMLParser {
    static func parse(
        from input: String,
        sourceName: String?
    ) -> Result<Self, ParsingError>
}
