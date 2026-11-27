import Foundation
import Testing

@testable import MiriCore

@MainActor struct ShortcutSearchTests {
    private let us = KeyLayout(inputSourceID: "com.apple.keylayout.US")!
    private let focusWest = ShortcutAction.engine(command: "window_focus_west")
    private let focusEast = ShortcutAction.engine(command: "window_focus_east")
    private let maximize = ShortcutAction.engine(command: "window_maximize")
    private let center = ShortcutAction.engine(command: "window_center")
    private let jump3 = ShortcutAction.engine(command: "window_focus_3")
    private let stackWest = ShortcutAction.engine(command: "window_stack_west")

    private func defaultShortcuts() throws -> Shortcuts {
        let document = try DefaultBinding.adding(to: try TOMLDocument(""), layout: us)
        return Shortcuts(document: document, layout: us)
    }

    private func search(_ query: String, index: ShortcutSearch = ShortcutSearch(bundle: .main)) throws
        -> [ShortcutAction]
    {
        index.filter(ShortcutAction.editable, query: query, shortcuts: try defaultShortcuts())
    }

    /// Compiles `Localization/Localizable.xcstrings` into a temporary bundle so tests exercise the real catalog
    /// across all shipped languages.
    private func withCompiledCatalogBundle(_ body: (Bundle) throws -> Void) throws {
        let repoRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalog = repoRoot.appending(path: "Localization/Localizable.xcstrings")
        let tempDir = FileManager.default.temporaryDirectory.appending(
            path: "miri-shortcut-search-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = ["xcstringstool", "compile", catalog.path(), "--output-directory", tempDir.path()]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let bundle = try #require(Bundle(url: tempDir))
        try body(bundle)
    }

    @Test func emptyAndWhitespaceQueriesKeepDefaultOrder() throws {
        #expect(try search("") == ShortcutAction.editable)
        #expect(try search("   \t\n  ") == ShortcutAction.editable)
    }

    @Test func matchesMultiWordOutOfOrderAndTypoQueries() throws {
        #expect(try search("focus left").contains(focusWest))
        #expect(try search("left focus").contains(focusWest))
        #expect(try search("center").first == center)
        #expect(try search("maximise").first == maximize)
        #expect(try search("fucus left").contains(focusWest))
        #expect(try search("center colunm").first == center)
        #expect(try search("focus banana").isEmpty)
    }

    @Test func matchesAcronymsAndCompactSubsequences() throws {
        #expect(try search("fcl").first == focusWest)
        #expect(try search("maxwin").first == maximize)
        #expect(try search("focleft").first == focusWest)
        #expect(try search("stck").contains(stackWest))
        #expect(try search("qxz").isEmpty)
        #expect(try search("zzzz").isEmpty)
    }

    @Test func matchesShortcutChordsWithoutTypoFalsePositives() throws {
        #expect(try search("⌃⌥F").first == maximize)
        #expect(try search("⌃F").contains(maximize))
        #expect(try search("←").contains(focusWest))
        // ⌃⌥H and ⌃⌥J are 1 edit apart; searching ⌃⌥H must not match an action bound only to ⌃⌥J.
        let hMatches = try search("⌃⌥H")
        #expect(hMatches.contains(focusWest))
        #expect(!hMatches.contains(.engine(command: "window_focus_south")))
    }

    @Test func matchesOtherEngineBindings() throws {
        let shortcuts = Shortcuts(
            document: try TOMLDocument("[bindings]\nwindow_virtual_2 = \"ctrl+alt+cmd-2\"\n"), layout: us)
        let index = ShortcutSearch(bundle: .main)
        #expect(index.filterOthers(query: "virtual", shortcuts: shortcuts) == shortcuts.others)
        #expect(index.filterOthers(query: "vrtual", shortcuts: shortcuts) == shortcuts.others)
        #expect(index.filterOthers(query: "⌃⌥⌘2", shortcuts: shortcuts) == shortcuts.others)
        #expect(index.filterOthers(query: "nonexistent", shortcuts: shortcuts).isEmpty)
    }

    @Test func searchesAcrossAllShippedLanguagesFromCompiledCatalog() throws {
        try withCompiledCatalogBundle { bundle in
            let index = ShortcutSearch(bundle: bundle)
            // Verify every single shipped language finds Focus column left, interpolated Jump to column 3, and Stop.
            let queriesByLanguage: [(String, String, ShortcutAction)] = [
                ("en", "Focus column left", focusWest),
                ("zh-Hans", "聚焦左侧列", focusWest),
                ("zh-Hant", "聚焦左側欄", focusWest),
                ("ja", "左の列にフォーカス", focusWest),
                ("ko", "왼쪽 열로 초점 이동", focusWest),
                ("de", "Fokus auf linke Spalte", focusWest),
                ("fr", "Activer la colonne de gauche", focusWest),
                ("es", "Activar columna de la izquierda", focusWest),
                ("it", "Attiva colonna a sinistra", focusWest),
                ("pt-BR", "Focar coluna à esquerda", focusWest),
                ("ru", "Фокус на колонку слева", focusWest),
                ("uk", "Фокус на колонку ліворуч", focusWest),
                ("ar", "نقل التركيز إلى العمود الأيسر", focusWest),
                ("hi", "फ़ोकस बाएँ कॉलम पर मूव करें", focusWest),
                ("nl", "Focus op linkerkolom", focusWest),
                ("tr", "Odağı soldaki sütuna taşı", focusWest),
                ("pl", "Przejdź do kolumny po lewej", focusWest),
                ("id", "Fokus ke kolom kiri", focusWest),
                ("vi", "Chuyển tiêu điểm sang cột bên trái", focusWest),
                ("th", "โฟกัสคอลัมน์ทางซ้าย", focusWest),
                ("sv", "Fokusera kolumn till vänster", focusWest),
                // Interpolated action titles across scripts.
                ("zh-Hans-jump", "跳到第 3 列", jump3),
                ("ja-jump", "3番目の列へ移動", jump3),
                ("ar-jump", "الانتقال إلى العمود 3", jump3),
                // Stop action across scripts, including distinct Brazilian and European Portuguese titles.
                ("pt-BR-stop", "Parar gerenciador de janelas", .stop),
                ("pt-PT-stop", "Parar gestor de janelas", .stop),
                ("zh-Hans-stop", "停止窗口管理器", .stop),
                ("ja-stop", "ウインドウマネージャを停止", .stop),
            ]
            for (label, query, expected) in queriesByLanguage {
                let results = try search(query, index: index)
                #expect(
                    results.first == expected, "\(label): expected \(expected) first for \"\(query)\", got \(results)")
            }

            // Cross-language fuzzy, diacritic-insensitive, Turkish-casing, and CJK partial-typo/subsequence queries.
            #expect(try search("聚焦列", index: index).contains(focusWest))
            #expect(try search("聚焦 左", index: index).contains(focusWest))
            #expect(try search("聚焦左测列", index: index).first == focusWest)
            #expect(try search("向左移东", index: index).first == .engine(command: "window_swap_west"))
            #expect(try search("窗口管里器", index: index).first == .stop)
            #expect(try search("最大化窗口", index: index).first == maximize)
            #expect(try search("ウィンドウ", index: index).contains(maximize))
            #expect(try search("左列", index: index).contains(focusWest))
            #expect(try search("YIĞ", index: index).contains(stackWest))
            #expect(try search("focar coluna a esquerda", index: index).first == focusWest)
            #expect(try search("cot ben trai", index: index).contains(focusWest))
            #expect(try search("العمود الايسر", index: index).contains(focusWest))
            // Full-width digits fold to half-width.
            #expect(try search("跳到第 ３ 列", index: index).first == jump3)
        }
    }
}
