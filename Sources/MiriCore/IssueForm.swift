import Foundation

/// An issue form on GitHub that Miri can open, named by its file in `.github/ISSUE_TEMPLATE/`.
public enum IssueForm: String, CaseIterable, Sendable {
    case bugReport = "bug_report.yml"
    case featureRequest = "feature_request.yml"

    /// The repository's new-issue page with this form selected.
    /// The address names only the form, so opening it sends nothing from the Mac.
    public var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/samanyudas/miri/issues/new"
        components.queryItems = [URLQueryItem(name: "template", value: rawValue)]
        return components.url!
    }
}
