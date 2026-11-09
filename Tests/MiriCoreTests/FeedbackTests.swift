import Foundation
import Testing

@testable import MiriCore

struct FeedbackTests {
    static let templates = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "../../.github/ISSUE_TEMPLATE").standardized

    @Test func sendFeedbackOpensTheListOfIssueForms() {
        #expect(Feedback.formList.absoluteString == "https://github.com/samanyudas/miri/issues/new/choose")
    }

    @Test func bugReportNamesATemplateThatExists() {
        let template = Self.templates.appending(path: Feedback.bugReportForm)
        #expect(FileManager.default.fileExists(atPath: template.path), "missing \(template.path)")
    }

    @Test func bugReportOpensTheNewIssuePageWithOnlyTheTemplate() throws {
        let components = try #require(URLComponents(url: Feedback.bugReport, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "github.com")
        #expect(components.path == "/samanyudas/miri/issues/new")
        #expect(components.queryItems == [URLQueryItem(name: "template", value: Feedback.bugReportForm)])
    }

    /// Copy and Open Bug Report leaves the person to paste the report into this field.
    @Test func bugReportFormHasADiagnosticsField() throws {
        let text = try String(contentsOf: Self.templates.appending(path: Feedback.bugReportForm), encoding: .utf8)
        #expect(text.contains("id: diagnostics"))
    }
}
