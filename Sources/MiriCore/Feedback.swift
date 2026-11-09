import Foundation

/// The GitHub pages where a person reports a bug or asks for a feature.
/// Each address names only a page or a form and fills in no field, so opening one sends nothing from the Mac.
public enum Feedback {
    /// GitHub's list of the repository's issue forms, where the person picks one.
    public static let formList = issuesPage("new/choose")

    /// The file of the bug report form in `.github/ISSUE_TEMPLATE/`.
    public static let bugReportForm = "bug_report.yml"

    /// The new-issue page with the bug report form selected.
    public static let bugReport = issuesPage("new", template: bugReportForm)

    private static func issuesPage(_ path: String, template: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/samanyudas/miri/issues/\(path)"
        if let template { components.queryItems = [URLQueryItem(name: "template", value: template)] }
        return components.url!
    }
}
