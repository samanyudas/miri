import Foundation
import Testing

@testable import MiriCore

struct TOMLParsingTests {
    @Test func readsScalarsTablesAndArrays() throws {
        let document = try TOMLDocument(
            """
            # Comment
            title = "Miri" # trailing
            literal = 'C:\\path'
            count = 1_000
            hex = 0xff
            ratio = 0.66
            exponent = 5e-1
            enabled = true
            day = 1979-05-27
            moment = 1979-05-27 07:32:00Z
            [options]
            preset_column_widths = [
              0.25, # first
              0.5,
            ]
            [windows.all]
            title = ".*"
            inline = { a = 1, b.c = "x" }
            [[rules]]
            name = "one"
            [[rules]]
            name = "two"
            """)
        #expect(document.value(at: ["title"]) == .string("Miri"))
        #expect(document.value(at: ["literal"]) == .string("C:\\path"))
        #expect(document.value(at: ["count"]) == .integer(1000))
        #expect(document.value(at: ["hex"]) == .integer(255))
        #expect(document.value(at: ["ratio"]) == .float(0.66))
        #expect(document.value(at: ["exponent"]) == .float(0.5))
        #expect(document.value(at: ["enabled"]) == .boolean(true))
        #expect(document.value(at: ["day"]) == .dateTime("1979-05-27"))
        #expect(document.value(at: ["moment"]) == .dateTime("1979-05-27 07:32:00Z"))
        #expect(document.value(at: ["options", "preset_column_widths"]) == .array([.float(0.25), .float(0.5)]))
        #expect(document.value(at: ["windows", "all", "inline", "b", "c"]) == .string("x"))
        #expect(
            document.value(at: ["rules"])
                == .array([.table(["name": .string("one")]), .table(["name": .string("two")])]))
    }

    @Test func readsStringEscapesAndMultilineStrings() throws {
        let document = try TOMLDocument(
            #"""
            escaped = "tab\tquote\"unicode\u00E9"
            multi = """
            first \
              second"""
            raw = '''
            keep \n this'''
            quotes = """a""\""""
            "quoted key" = 1
            """#)
        #expect(document.value(at: ["escaped"]) == .string("tab\tquote\"unicode\u{E9}"))
        #expect(document.value(at: ["multi"]) == .string("first second"))
        #expect(document.value(at: ["raw"]) == .string("keep \\n this"))
        #expect(document.value(at: ["quotes"]) == .string("a\"\"\""))
        #expect(document.value(at: ["quoted key"]) == .integer(1))
    }

    @Test(arguments: [
        ("a = 1\na = 2", 2, "defined twice"),
        ("[a]\n[a]", 2, "defined twice"),
        ("a = ", 1, "Expected a value"),
        ("a = \"open", 1, "Unterminated"),
        ("a = [1, 2", 1, "Expected , or ]"),
        ("a = 1 b = 2", 1, "Expected a newline"),
        ("a = { b = 1 }\n[a]", 2, "already defined"),
        ("a = 01", 1, "Invalid value"),
        ("ok = 1\n\nbad = nope", 3, "Invalid value"),
        ("a.b = 1\n[a]", 2, "defined twice"),
        ("[a.b]\n[a]\nb.c = 1", 3, "dotted key"),
    ])
    func reportsErrorsWithLines(source: String, line: Int, message: String) {
        #expect {
            try TOMLDocument(source)
        } throws: { error in
            guard let error = error as? TOMLError else { return false }
            return error.line == line && error.message.contains(message)
        }
    }

    @Test(arguments: ["Cargo.toml", "Cargo.lock"])
    func readsRealEngineManifests(name: String) throws {
        let text = try String(contentsOf: engineDirectory.appending(path: name), encoding: .utf8)
        let document = try TOMLDocument(text)
        #expect(document.value(at: name == "Cargo.toml" ? ["package", "name"] : ["version"]) != nil)
    }

    @Test func readsEveryTOMLExampleInTheEngineDocumentation() throws {
        let markdown = try String(contentsOf: engineDirectory.appending(path: "CONFIGURATION.md"), encoding: .utf8)
        let blocks = markdown.matches(of: /```toml\n([\s\S]*?)```/).map { String($0.1) }
        #expect(blocks.count > 5)
        for block in blocks {
            #expect(throws: Never.self, "\(block)") { try TOMLDocument(block) }
        }
    }

    private var engineDirectory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../vendor/paneru").standardized
    }
}

struct TOMLEditingTests {
    private let source = """
        # Miri configuration
        [options]
        preset_column_widths = [0.25, 0.5] # keep this comment
        focus_follows_mouse = false

        # Padding section
        [padding]
        top = 4

        [windows.firefox]
        bundle_id = "org.mozilla.firefox"
        """

    @Test func replacesAValueInPlaceAndKeepsComments() throws {
        let document = try TOMLDocument(source).setting(
            .array([.float(0.33), .float(0.66)]), table: ["options"], key: "preset_column_widths")
        #expect(
            document.text
                == source.replacing(
                    "[0.25, 0.5] # keep this comment", with: "[0.33, 0.66] # keep this comment"))
    }

    @Test func insertsAMissingKeyAtTheEndOfItsTable() throws {
        let document = try TOMLDocument(source).setting(.integer(4), table: ["padding"], key: "left")
        #expect(document.text == source.replacing("top = 4\n", with: "top = 4\nleft = 4\n"))
    }

    @Test func appendsAMissingTable() throws {
        let document = try TOMLDocument(source).setting(.boolean(true), table: ["miri"], key: "launch_at_login")
        #expect(document.text == source + "\n\n[miri]\nlaunch_at_login = true\n")
        let empty = try TOMLDocument("").setting(.integer(8), table: ["miri"], key: "inner_gap")
        #expect(empty.text == "[miri]\ninner_gap = 8\n")
    }

    @Test func insertsAfterAHeaderWithoutStatements() throws {
        let document = try TOMLDocument("[miri]\n[options]\n").setting(.integer(1), table: ["miri"], key: "a")
        #expect(document.text == "[miri]\na = 1\n[options]\n")
    }

    @Test func removesOnlyTheStatementLine() throws {
        let document = try TOMLDocument(source).removing(table: ["options"], key: "focus_follows_mouse")
        #expect(document.text == source.replacing("focus_follows_mouse = false\n", with: ""))
        let unchanged = try document.removing(table: ["options"], key: "missing")
        #expect(unchanged.text == document.text)
    }

    @Test func refusesKeysDefinedInFormsItDoesNotRewrite() throws {
        let inline = try TOMLDocument("padding = { top = 1 }\n")
        #expect(throws: TOMLEditError.notEditable(path: "padding.top")) {
            try inline.setting(.integer(2), table: ["padding"], key: "top")
        }
        #expect(throws: TOMLEditError.notEditable(path: "padding.left")) {
            try inline.setting(.integer(2), table: ["padding"], key: "left")
        }
        let dotted = try TOMLDocument("padding.top = 1\n")
        #expect(throws: TOMLEditError.notEditable(path: "padding.top")) {
            try dotted.setting(.integer(2), table: ["padding"], key: "top")
        }
    }

    @Test func encodesValuesThatReadBackUnchanged() throws {
        let values: [TOMLValue] = [
            .string("quote \" backslash \\ newline \n"), .float(1), .float(0.33), .float(-2.5e-7),
            .integer(-3), .boolean(false), .array([]), .array([.string("a"), .integer(1)]),
        ]
        for value in values {
            let document = try TOMLDocument("").setting(value, table: ["t"], key: "key with space")
            #expect(document.value(at: ["t", "key with space"]) == value)
        }
    }
}
