/// Why Miri refused to change a TOML document.
public enum TOMLEditError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The key exists, but in a form Miri does not rewrite, such as an inline table or a dotted key in a parent table.
    case notEditable(path: String)
    /// The edited text did not read back with the requested value. Miri keeps the original file.
    case verificationFailed(path: String)

    public var description: String {
        switch self {
        case .notEditable(let path):
            "Miri cannot change \(path) because the file defines it in a form Miri does not rewrite. Edit it by hand."
        case .verificationFailed(let path):
            "Miri could not change \(path) safely, so the file was left unchanged."
        }
    }
}

extension TOMLDocument {
    /// Returns a copy with one value set, keeping every other byte of the file, including comments and ordering.
    public func setting(_ value: TOMLValue, table: [String], key: String) throws -> TOMLDocument {
        let path = (table + [key]).map(TOMLValue.encodeKey).joined(separator: ".")
        let edited: String
        if let assignment = editableAssignment(table: table, key: key) {
            edited = replacing(assignment.value, with: value.encoded)
        } else if self.value(at: table + [key]) != nil {
            throw TOMLEditError.notEditable(path: path)
        } else if let offset = insertionOffset(for: table) {
            edited = inserting("\(TOMLValue.encodeKey(key)) = \(value.encoded)\n", at: offset)
        } else if table.isEmpty || self.value(at: table) != nil {
            throw TOMLEditError.notEditable(path: path)
        } else {
            let header = table.map(TOMLValue.encodeKey).joined(separator: ".")
            var suffix = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
            if !text.isEmpty { suffix += "\n" }
            edited = text + suffix + "[\(header)]\n\(TOMLValue.encodeKey(key)) = \(value.encoded)\n"
        }
        let result = try TOMLDocument(edited)
        guard result.value(at: table + [key]) == value else { throw TOMLEditError.verificationFailed(path: path) }
        return result
    }

    /// Returns a copy without the key's statement line. A missing key leaves the document unchanged.
    public func removing(table: [String], key: String) throws -> TOMLDocument {
        guard let assignment = editableAssignment(table: table, key: key) else {
            guard value(at: table + [key]) == nil else {
                throw TOMLEditError.notEditable(path: (table + [key]).map(TOMLValue.encodeKey).joined(separator: "."))
            }
            return self
        }
        var scalars = Array(text.unicodeScalars)
        scalars.removeSubrange(assignment.lineStart..<assignment.lineEnd)
        return try TOMLDocument(String(String.UnicodeScalarView(scalars)))
    }

    private func editableAssignment(table: [String], key: String) -> Assignment? {
        assignments.first { $0.table == table && $0.key == [key] && !$0.inTableArray }
    }

    /// The offset just after the last statement of a table that has its own `[header]`.
    private func insertionOffset(for table: [String]) -> Int? {
        if table.isEmpty {
            let firstHeader = headers.first?.lineEnd ?? Int.max
            let rootStatements = assignments.filter { $0.table.isEmpty && $0.lineEnd <= firstHeader }
            return rootStatements.last?.lineEnd ?? (headers.isEmpty ? text.unicodeScalars.count : 0)
        }
        guard let header = headers.first(where: { $0.path == table && !$0.isArray }) else { return nil }
        let statements = assignments.filter { $0.table == table && !$0.inTableArray && $0.lineEnd > header.lineEnd }
        let nextHeader = headers.first { $0.lineEnd > header.lineEnd }?.lineEnd ?? Int.max
        return statements.last { $0.lineEnd < nextHeader }?.lineEnd ?? header.lineEnd
    }

    private func replacing(_ range: Range<Int>, with replacement: String) -> String {
        var scalars = Array(text.unicodeScalars)
        scalars.replaceSubrange(range, with: replacement.unicodeScalars)
        return String(String.UnicodeScalarView(scalars))
    }

    private func inserting(_ line: String, at offset: Int) -> String {
        var scalars = Array(text.unicodeScalars)
        let needsNewline = offset > 0 && scalars[offset - 1] != "\n"
        scalars.insert(contentsOf: ((needsNewline ? "\n" : "") + line).unicodeScalars, at: offset)
        return String(String.UnicodeScalarView(scalars))
    }
}
