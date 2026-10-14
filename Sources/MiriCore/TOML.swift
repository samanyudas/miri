import Foundation

/// A parsed TOML value. Date and time values keep their source text, because Miri never interprets them.
public enum TOMLValue: Equatable, Sendable {
    case string(String)
    case integer(Int64)
    case float(Double)
    case boolean(Bool)
    case dateTime(String)
    case array([TOMLValue])
    case table([String: TOMLValue])

    public subscript(key: String) -> TOMLValue? {
        if case .table(let entries) = self { entries[key] } else { nil }
    }

    /// Encodes the value as TOML source text. Tables encode as inline tables.
    public var encoded: String {
        switch self {
        case .string(let value): TOMLValue.quote(value)
        case .integer(let value): String(value)
        case .float(let value):
            if value.isNaN {
                "nan"
            } else if value.isInfinite {
                value < 0 ? "-inf" : "inf"
            } else if value == value.rounded(), abs(value) < 1e15 {
                String(format: "%.1f", value)
            } else {
                "\(value)"
            }
        case .boolean(let value): value ? "true" : "false"
        case .dateTime(let value): value
        case .array(let values): "[" + values.map(\.encoded).joined(separator: ", ") + "]"
        case .table(let entries):
            entries.isEmpty
                ? "{}"
                : "{ "
                    + entries.sorted { $0.key < $1.key }.map { "\(TOMLValue.encodeKey($0.key)) = \($0.value.encoded)" }
                    .joined(separator: ", ") + " }"
        }
    }

    static func quote(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            case _ where scalar.value < 0x20 || scalar.value == 0x7F:
                result += String(format: "\\u%04X", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    static func encodeKey(_ key: String) -> String {
        let bare = !key.isEmpty && key.unicodeScalars.allSatisfy(TOMLParser.isBareKey)
        return bare ? key : quote(key)
    }
}

/// A syntax or semantic error, with the one-based line where it occurred.
public struct TOMLError: Error, Equatable, Sendable, CustomStringConvertible {
    public let line: Int
    public let message: String

    public var description: String { "Line \(line): \(message)" }
}

/// A TOML document that remembers where each statement is, so Miri can change one value without touching the rest.
public struct TOMLDocument: Sendable {
    /// One `key = value` statement and its position, as offsets into the document's Unicode scalars.
    struct Assignment: Sendable {
        let table: [String]
        let key: [String]
        let inTableArray: Bool
        let value: Range<Int>
        /// Offset just past the statement's final newline, or the end of the document.
        let lineEnd: Int
        /// Offset of the first character on the statement's first line.
        let lineStart: Int
    }

    struct Header: Sendable {
        let path: [String]
        let isArray: Bool
        let lineEnd: Int
    }

    public let text: String
    public let root: TOMLValue
    let assignments: [Assignment]
    let headers: [Header]

    public init(_ text: String) throws(TOMLError) {
        var parser = TOMLParser(text)
        try parser.parse()
        self.text = text
        root = parser.root.value
        assignments = parser.assignments
        headers = parser.headers
    }

    public func value(at path: [String]) -> TOMLValue? {
        path.reduce(Optional(root)) { $0?[$1] }
    }
}

/// Builds TOML documents while tracking which tables were defined by headers, dotted keys, or inline tables.
struct TOMLParser {
    final class Table {
        enum Origin { case implicit, header, dotted, inline }
        var origin: Origin
        var entries: [String: Entry] = [:]

        init(_ origin: Origin) { self.origin = origin }

        var value: TOMLValue {
            .table(
                entries.mapValues { entry in
                    switch entry {
                    case .value(let value): value
                    case .table(let table): table.value
                    case .tableArray(let tables): .array(tables.map(\.value))
                    }
                })
        }
    }

    enum Entry {
        case value(TOMLValue)
        case table(Table)
        case tableArray([Table])
    }

    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var line = 1
    let root = Table(.header)
    private var current: Table
    private var currentPath: [String] = []
    private var currentIsArray = false
    private(set) var assignments: [TOMLDocument.Assignment] = []
    private(set) var headers: [TOMLDocument.Header] = []

    init(_ text: String) {
        scalars = Array(text.unicodeScalars)
        current = root
    }

    static func isBareKey(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "A"..."Z", "a"..."z", "0"..."9", "_", "-": true
        default: false
        }
    }

    private var peek: Unicode.Scalar? { index < scalars.count ? scalars[index] : nil }

    private func peek(_ offset: Int) -> Unicode.Scalar? {
        index + offset < scalars.count ? scalars[index + offset] : nil
    }

    private func fail(_ message: String) -> TOMLError { TOMLError(line: line, message: message) }

    private func starts(with text: String) -> Bool {
        var offset = 0
        for scalar in text.unicodeScalars {
            guard peek(offset) == scalar else { return false }
            offset += 1
        }
        return true
    }

    private mutating func advance() {
        if scalars[index] == "\n" { line += 1 }
        index += 1
    }

    private mutating func skipSpaces() {
        while let scalar = peek, scalar == " " || scalar == "\t" { index += 1 }
    }

    private mutating func skipComment() throws(TOMLError) {
        guard peek == "#" else { return }
        while let scalar = peek, scalar != "\n" {
            if scalar == "\r", peek(1) == "\n" { break }
            try checkAllowed(scalar, inComment: true)
            index += 1
        }
    }

    private func checkAllowed(_ scalar: Unicode.Scalar, inComment: Bool) throws(TOMLError) {
        let control = scalar.value < 0x20 && scalar != "\t"
        if control || scalar.value == 0x7F {
            throw fail(inComment ? "Control characters are not allowed in comments." : "Unexpected control character.")
        }
    }

    /// Consumes the end of a line: optional spaces and a comment, then a newline or the end of the document.
    private mutating func expectLineEnd() throws(TOMLError) {
        skipSpaces()
        try skipComment()
        switch peek {
        case nil: return
        case "\n": advance()
        case "\r" where peek(1) == "\n":
            index += 1
            advance()
        default: throw fail("Expected a newline after the value.")
        }
    }

    /// Skips spaces, newlines, and comments between array elements.
    private mutating func skipArrayFiller() throws(TOMLError) {
        while true {
            skipSpaces()
            try skipComment()
            if peek == "\n" {
                advance()
            } else if peek == "\r", peek(1) == "\n" {
                index += 1
                advance()
            } else {
                return
            }
        }
    }

    mutating func parse() throws(TOMLError) {
        while true {
            skipSpaces()
            guard let scalar = peek else { return }
            switch scalar {
            case "#", "\n", "\r": try expectLineEnd()
            case "[": try parseHeader()
            default: try parseAssignment()
            }
        }
    }

    // MARK: Statements

    private mutating func parseHeader() throws(TOMLError) {
        index += 1
        let isArray = peek == "["
        if isArray { index += 1 }
        skipSpaces()
        let path = try parseKey()
        skipSpaces()
        guard peek == "]" else { throw fail("Expected ] to close the table header.") }
        index += 1
        if isArray {
            guard peek == "]" else { throw fail("Expected ]] to close the array of tables header.") }
            index += 1
        }
        let headerLine = line
        try expectLineEnd()
        do {
            current = try isArray ? appendTableArray(path) : defineTable(path)
        } catch {
            throw TOMLError(line: headerLine, message: error.message)
        }
        currentPath = path
        currentIsArray = isArray || path.indices.dropLast().contains { prefixIsTableArray(Array(path[...$0])) }
        headers.append(.init(path: path, isArray: isArray, lineEnd: index))
    }

    private func prefixIsTableArray(_ path: [String]) -> Bool {
        var table = root
        for (offset, key) in path.enumerated() {
            switch table.entries[key] {
            case .tableArray(let tables):
                if offset == path.count - 1 { return true }
                table = tables[tables.count - 1]
            case .table(let next): table = next
            default: return false
            }
        }
        return false
    }

    private func descend(_ path: ArraySlice<String>) throws(TOMLError) -> Table {
        var table = root
        for key in path {
            switch table.entries[key] {
            case nil:
                let next = Table(.implicit)
                table.entries[key] = .table(next)
                table = next
            case .table(let next):
                if next.origin == .inline { throw fail("Cannot extend the inline table \(key).") }
                table = next
            case .tableArray(let tables): table = tables[tables.count - 1]
            case .value: throw fail("The key \(key) is already defined as a value.")
            }
        }
        return table
    }

    private func defineTable(_ path: [String]) throws(TOMLError) -> Table {
        let parent = try descend(path.dropLast())
        let name = path[path.count - 1]
        switch parent.entries[name] {
        case nil:
            let table = Table(.header)
            parent.entries[name] = .table(table)
            return table
        case .table(let table) where table.origin == .implicit:
            table.origin = .header
            return table
        case .table: throw fail("The table \(path.joined(separator: ".")) is defined twice.")
        case .tableArray, .value: throw fail("The key \(path.joined(separator: ".")) is already defined.")
        }
    }

    private func appendTableArray(_ path: [String]) throws(TOMLError) -> Table {
        let parent = try descend(path.dropLast())
        let name = path[path.count - 1]
        let table = Table(.header)
        switch parent.entries[name] {
        case nil: parent.entries[name] = .tableArray([table])
        case .tableArray(let tables): parent.entries[name] = .tableArray(tables + [table])
        default: throw fail("The key \(path.joined(separator: ".")) is already defined.")
        }
        return table
    }

    private mutating func parseAssignment() throws(TOMLError) {
        var lineStart = index
        while lineStart > 0, scalars[lineStart - 1] != "\n" { lineStart -= 1 }
        let statementLine = line
        let (key, value, range) = try parseKeyValue()
        do {
            try assign(value, to: key, in: current)
        } catch {
            throw TOMLError(line: statementLine, message: error.message)
        }
        try expectLineEnd()
        assignments.append(
            .init(
                table: currentPath, key: key, inTableArray: currentIsArray, value: range, lineEnd: index,
                lineStart: lineStart))
    }

    private mutating func parseKeyValue() throws(TOMLError) -> ([String], TOMLValue, Range<Int>) {
        let key = try parseKey()
        skipSpaces()
        guard peek == "=" else { throw fail("Expected = after the key \(key.joined(separator: ".")).") }
        index += 1
        skipSpaces()
        let start = index
        let value = try parseValue()
        return (key, value, start..<index)
    }

    private func assign(_ value: TOMLValue, to key: [String], in table: Table) throws(TOMLError) {
        var target = table
        for name in key.dropLast() {
            switch target.entries[name] {
            case nil:
                let next = Table(.dotted)
                target.entries[name] = .table(next)
                target = next
            case .table(let next) where next.origin == .dotted || next.origin == .implicit:
                next.origin = .dotted
                target = next
            default: throw fail("Cannot add dotted key \(key.joined(separator: ".")) to an existing value or table.")
            }
        }
        let name = key[key.count - 1]
        guard target.entries[name] == nil else {
            throw fail("The key \(key.joined(separator: ".")) is defined twice.")
        }
        target.entries[name] = .value(value)
    }

    // MARK: Keys

    private mutating func parseKey() throws(TOMLError) -> [String] {
        var parts = [try parseSimpleKey()]
        while true {
            let save = index
            skipSpaces()
            guard peek == "." else {
                index = save
                return parts
            }
            index += 1
            skipSpaces()
            parts.append(try parseSimpleKey())
        }
    }

    private mutating func parseSimpleKey() throws(TOMLError) -> String {
        switch peek {
        case "\"":
            if starts(with: "\"\"\"") { throw fail("Multi-line strings cannot be keys.") }
            return try parseBasicString()
        case "'":
            if starts(with: "'''") { throw fail("Multi-line strings cannot be keys.") }
            return try parseLiteralString()
        default:
            let start = index
            while let scalar = peek, TOMLParser.isBareKey(scalar) { index += 1 }
            guard index > start else { throw fail("Expected a key.") }
            return String(String.UnicodeScalarView(scalars[start..<index]))
        }
    }

    // MARK: Values

    private mutating func parseValue() throws(TOMLError) -> TOMLValue {
        guard let scalar = peek else { throw fail("Expected a value.") }
        switch scalar {
        case "\"":
            return .string(starts(with: "\"\"\"") ? try parseMultilineBasicString() : try parseBasicString())
        case "'":
            return .string(starts(with: "'''") ? try parseMultilineLiteralString() : try parseLiteralString())
        case "[": return try parseArray()
        case "{": return try parseInlineTable()
        default:
            if starts(with: "true") && !continuesToken(after: 4) {
                index += 4
                return .boolean(true)
            }
            if starts(with: "false") && !continuesToken(after: 5) {
                index += 5
                return .boolean(false)
            }
            return try parseNumberOrDate()
        }
    }

    private func continuesToken(after length: Int) -> Bool {
        guard let next = peek(length) else { return false }
        return TOMLParser.isBareKey(next) || next == "." || next == ":" || next == "+"
    }

    private mutating func parseArray() throws(TOMLError) -> TOMLValue {
        index += 1
        var values: [TOMLValue] = []
        while true {
            try skipArrayFiller()
            if peek == "]" {
                index += 1
                return .array(values)
            }
            values.append(try parseValue())
            try skipArrayFiller()
            switch peek {
            case ",": index += 1
            case "]":
                index += 1
                return .array(values)
            default: throw fail("Expected , or ] in the array.")
            }
        }
    }

    private mutating func parseInlineTable() throws(TOMLError) -> TOMLValue {
        index += 1
        let table = Table(.inline)
        skipSpaces()
        if peek == "}" {
            index += 1
            return table.value
        }
        while true {
            skipSpaces()
            let (key, value, _) = try parseKeyValue()
            try assign(value, to: key, in: table)
            skipSpaces()
            switch peek {
            case ",": index += 1
            case "}":
                index += 1
                freeze(table)
                return table.value
            default: throw fail("Expected , or } in the inline table.")
            }
        }
    }

    private func freeze(_ table: Table) {
        table.origin = .inline
        for case .table(let child) in table.entries.values { freeze(child) }
    }

    private mutating func parseBasicString() throws(TOMLError) -> String {
        index += 1
        var result = String.UnicodeScalarView()
        while true {
            guard let scalar = peek, scalar != "\n" else { throw fail("Unterminated string.") }
            index += 1
            switch scalar {
            case "\"": return String(result)
            case "\\": result.append(try parseEscape())
            default:
                try checkAllowed(scalar, inComment: false)
                result.append(scalar)
            }
        }
    }

    private mutating func parseMultilineBasicString() throws(TOMLError) -> String {
        index += 3
        skipLeadingNewline()
        var result = String.UnicodeScalarView()
        while true {
            guard let scalar = peek else { throw fail("Unterminated multi-line string.") }
            if starts(with: "\"\"\"") {
                index += 3
                // Up to two quotes may directly precede the closing delimiter.
                for _ in 0..<2 where peek == "\"" {
                    result.append("\"")
                    index += 1
                }
                return String(result)
            }
            if scalar == "\\" {
                index += 1
                if try skipLineEndingBackslash() { continue }
                result.append(try parseEscape())
                continue
            }
            if scalar != "\n" && !(scalar == "\r" && peek(1) == "\n") { try checkAllowed(scalar, inComment: false) }
            result.append(scalar)
            advance()
        }
    }

    /// Handles a backslash at the end of a line in a multi-line basic string, which trims the following whitespace.
    private mutating func skipLineEndingBackslash() throws(TOMLError) -> Bool {
        var offset = 0
        while let scalar = peek(offset), scalar == " " || scalar == "\t" { offset += 1 }
        guard peek(offset) == "\n" || (peek(offset) == "\r" && peek(offset + 1) == "\n") else { return false }
        while let scalar = peek, scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" { advance() }
        return true
    }

    private mutating func skipLeadingNewline() {
        if peek == "\n" {
            advance()
        } else if peek == "\r", peek(1) == "\n" {
            index += 1
            advance()
        }
    }

    private mutating func parseEscape() throws(TOMLError) -> Unicode.Scalar {
        guard let scalar = peek else { throw fail("Unterminated escape sequence.") }
        index += 1
        switch scalar {
        case "b": return "\u{08}"
        case "t": return "\t"
        case "n": return "\n"
        case "f": return "\u{0C}"
        case "r": return "\r"
        case "e": return "\u{1B}"
        case "\"": return "\""
        case "\\": return "\\"
        case "u", "U":
            let length = scalar == "u" ? 4 : 8
            guard index + length <= scalars.count else { throw fail("Incomplete Unicode escape.") }
            let digits = String(String.UnicodeScalarView(scalars[index..<index + length]))
            index += length
            guard let code = UInt32(digits, radix: 16), let result = Unicode.Scalar(code) else {
                throw fail("Invalid Unicode escape \\\(scalar)\(digits).")
            }
            return result
        default: throw fail("Invalid escape sequence \\\(scalar).")
        }
    }

    private mutating func parseLiteralString() throws(TOMLError) -> String {
        index += 1
        let start = index
        while true {
            guard let scalar = peek, scalar != "\n" else { throw fail("Unterminated string.") }
            if scalar == "'" { break }
            try checkAllowed(scalar, inComment: false)
            index += 1
        }
        let result = String(String.UnicodeScalarView(scalars[start..<index]))
        index += 1
        return result
    }

    private mutating func parseMultilineLiteralString() throws(TOMLError) -> String {
        index += 3
        skipLeadingNewline()
        var result = String.UnicodeScalarView()
        while true {
            guard let scalar = peek else { throw fail("Unterminated multi-line string.") }
            if starts(with: "'''") {
                index += 3
                for _ in 0..<2 where peek == "'" {
                    result.append("'")
                    index += 1
                }
                return String(result)
            }
            if scalar != "\n" && !(scalar == "\r" && peek(1) == "\n") { try checkAllowed(scalar, inComment: false) }
            result.append(scalar)
            advance()
        }
    }

    private mutating func parseNumberOrDate() throws(TOMLError) -> TOMLValue {
        let start = index
        while let scalar = peek, TOMLParser.isBareKey(scalar) || "+.:".unicodeScalars.contains(scalar) {
            index += 1
        }
        // A space may separate the date and time of a date-time value.
        if peek == " ", let next = peek(1), ("0"..."9").contains(next), isDate(start..<index) {
            index += 1
            while let scalar = peek, TOMLParser.isBareKey(scalar) || "+.:".unicodeScalars.contains(scalar) {
                index += 1
            }
        }
        let token = String(String.UnicodeScalarView(scalars[start..<index]))
        guard !token.isEmpty else { throw fail("Expected a value.") }
        if let value = TOMLParser.number(token) { return value }
        if TOMLParser.isDateTime(token) { return .dateTime(token) }
        throw fail("Invalid value \(token).")
    }

    private func isDate(_ range: Range<Int>) -> Bool {
        let token = String(String.UnicodeScalarView(scalars[range]))
        return token.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil
    }

    static func number(_ token: String) -> TOMLValue? {
        switch token {
        case "inf", "+inf": return .float(.infinity)
        case "-inf": return .float(-.infinity)
        case "nan", "+nan", "-nan": return .float(.nan)
        default: break
        }
        if let match = token.wholeMatch(of: /0([xob])([0-9A-Fa-f]+(?:_[0-9A-Fa-f]+)*)/) {
            let radix =
                switch match.1 {
                case "x": 16
                case "o": 8
                default: 2
                }
            return Int64(match.2.replacing("_", with: ""), radix: radix).map(TOMLValue.integer)
        }
        if token.wholeMatch(of: /[+-]?(?:0|[1-9](?:_?\d)*)/) != nil {
            return Int64(token.replacing("_", with: "")).map(TOMLValue.integer)
        }
        let float = /[+-]?(?:0|[1-9](?:_?\d)*)(?:\.\d(?:_?\d)*)?(?:[eE][+-]?\d(?:_?\d)*)?/
        guard token.wholeMatch(of: float) != nil, token.contains(where: { ".eE".contains($0) }) else { return nil }
        return Double(token.replacing("_", with: "")).map(TOMLValue.float)
    }

    /// Accepts RFC 3339 dates and times with the field ranges TOML 1.0 requires, including seconds.
    static func isDateTime(_ token: String) -> Bool {
        let time = /(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?/
        if let match = token.wholeMatch(of: time) { return validTime(match.1, match.2, match.3) }
        let pattern = /(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:[zZ]|[+-](\d{2}):(\d{2}))?)?/
        guard let match = token.wholeMatch(of: pattern), let year = Int(match.1), let month = Int(match.2),
            let day = Int(match.3), (1...12).contains(month)
        else { return false }
        let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
        guard (1...days).contains(day) else { return false }
        if let hour = match.4, let minute = match.5, let second = match.6, !validTime(hour, minute, second) {
            return false
        }
        if let hour = match.7.flatMap({ Int($0) }), let minute = match.8.flatMap({ Int($0) }) {
            return hour < 24 && minute < 60
        }
        return true
    }

    private static func validTime(_ hour: Substring, _ minute: Substring, _ second: Substring) -> Bool {
        guard let hour = Int(hour), let minute = Int(minute), let second = Int(second) else { return false }
        return hour < 24 && minute < 60 && second <= 60
    }
}
