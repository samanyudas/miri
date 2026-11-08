import Foundation
import Testing

@testable import MiriCore

struct IssueFormTests {
    static let templates = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "../../.github/ISSUE_TEMPLATE").standardized

    @Test(arguments: IssueForm.allCases) func namesATemplateThatExists(_ form: IssueForm) {
        let template = Self.templates.appending(path: form.rawValue)
        #expect(FileManager.default.fileExists(atPath: template.path), "missing \(template.path)")
    }

    @Test(arguments: IssueForm.allCases) func opensTheNewIssuePageWithOnlyTheTemplate(_ form: IssueForm) throws {
        let components = try #require(URLComponents(url: form.url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "github.com")
        #expect(components.path == "/samanyudas/miri/issues/new")
        #expect(components.queryItems == [URLQueryItem(name: "template", value: form.rawValue)])
    }

    /// Report a Bug asks the person to paste Copy Diagnostics output into this field (#352).
    @Test func bugReportFormHasADiagnosticsField() throws {
        let text = try String(contentsOf: Self.templates.appending(path: IssueForm.bugReport.rawValue), encoding: .utf8)
        #expect(text.contains("id: diagnostics"))
    }
}
