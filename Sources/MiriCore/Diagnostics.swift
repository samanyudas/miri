import Foundation

/// Removes personal details from text before it leaves the Mac: window titles, user names, and document paths.
public struct Redactor: Sendable {
    public let homeDirectory: String
    public let userNames: [String]
    /// Exact strings to remove, such as the titles of open windows. Strings shorter than three characters are kept.
    public let sensitiveStrings: [String]

    public init(homeDirectory: String, userNames: [String], sensitiveStrings: [String] = []) {
        self.homeDirectory = homeDirectory
        self.userNames = userNames.filter { $0.count >= 2 }
        self.sensitiveStrings = sensitiveStrings.filter { $0.count >= 3 }.sorted { $0.count > $1.count }
    }

    public func redact(_ text: String) -> String {
        var result = text.replacing(/\x1B\[[0-9;]*[A-Za-z]/, with: "")
        for secret in sensitiveStrings { result = result.replacing(secret, with: "<title>") }
        if homeDirectory.count > 1 { result = result.replacing(homeDirectory, with: "~") }
        result = result.replacing(/(["'`])(?:(?!\1)[^\n])*\1/) { "\($0.1)<redacted>\($0.1)" }
        result = result.replacing(/(?:~|\/Users|\/Volumes|\/private\/var\/folders)\/[^\s"'`,;)\]]+/, with: "<path>")
        for name in userNames {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            if let pattern = try? Regex("(?i)\\b\(escaped)\\b") { result = result.replacing(pattern, with: "<user>") }
        }
        return result
    }
}

/// The facts a diagnostics report contains. It never holds window titles, document paths, or raw configuration.
public struct DiagnosticsReport: Sendable {
    public struct Display: Sendable {
        public let width: Int
        public let height: Int
        public let scale: Double
        public let x: Int
        public let y: Int
        public let isMain: Bool

        public init(width: Int, height: Int, scale: Double, x: Int, y: Int, isMain: Bool) {
            (self.width, self.height, self.scale, self.x, self.y, self.isMain) = (width, height, scale, x, y, isMain)
        }
    }

    public var appVersion: String
    public var engineRevision: String
    public var macOSVersion: String
    public var architecture: String
    public var displays: [Display]
    public var engineState: EngineState
    public var setupChecks: [SetupCheck]
    public var configurationIssue: ConfigurationIssue?
    public var log: String

    public init(
        appVersion: String, engineRevision: String, macOSVersion: String, architecture: String, displays: [Display],
        engineState: EngineState, setupChecks: [SetupCheck], configurationIssue: ConfigurationIssue?, log: String
    ) {
        self.appVersion = appVersion
        self.engineRevision = engineRevision
        self.macOSVersion = macOSVersion
        self.architecture = architecture
        self.displays = displays
        self.engineState = engineState
        self.setupChecks = setupChecks
        self.configurationIssue = configurationIssue
        self.log = log
    }

    /// Markdown for a GitHub issue, in the language that `bundle` picks for the Mac.
    /// Everything that could carry personal text goes through the redactor.
    public func rendered(with redactor: Redactor, bundle: Bundle = .main) -> String {
        var lines = [
            String(localized: "## Miri diagnostics", bundle: bundle), "",
            String(localized: "- Miri: \(appVersion)", bundle: bundle),
            String(localized: "- Engine: \(engineRevision)", bundle: bundle),
            String(localized: "- macOS: \(macOSVersion) (\(architecture))", bundle: bundle),
            String(localized: "- Engine status: \(Self.describe(engineState, bundle: bundle))", bundle: bundle),
            String(
                localized:
                    "- Configuration: \(configurationIssue.map { redactor.redact($0.description) } ?? String(localized: "valid", bundle: bundle))",
                bundle: bundle),
            "", String(localized: "### Displays", bundle: bundle), "",
        ]
        for (index, display) in displays.enumerated() {
            // Plain digits, without the grouping separators of a localized number, so reports compare across languages.
            let (number, width, height) = (String(index + 1), String(display.width), String(display.height))
            let (scale, x, y) = (display.scale.formatted(), String(display.x), String(display.y))
            lines.append(
                display.isMain
                    ? String(
                        localized:
                            "- Display \(number) (main): \(width) x \(height) points at \(scale)x, origin (\(x), \(y))",
                        bundle: bundle)
                    : String(
                        localized: "- Display \(number): \(width) x \(height) points at \(scale)x, origin (\(x), \(y))",
                        bundle: bundle)
            )
        }
        lines += ["", String(localized: "### Setup checks", bundle: bundle), ""]
        for check in setupChecks { lines.append("- \(check.title): \(Self.describe(check.status, bundle: bundle))") }
        lines += [
            "", String(localized: "### Engine log (redacted)", bundle: bundle), "", "```",
            redactor.redact(log).trimmingCharacters(in: .newlines), "```",
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    static func describe(_ state: EngineState, bundle: Bundle) -> String {
        switch state {
        case .stopped: String(localized: "stopped", bundle: bundle)
        case .running: String(localized: "running", bundle: bundle)
        case .restarting(let crashes): String(localized: "restarting after \(crashes) crashes", bundle: bundle)
        case .failed(let reason): String(localized: "failed: \(reason)", bundle: bundle)
        }
    }

    static func describe(_ status: SetupStatus, bundle: Bundle) -> String {
        switch status {
        case .passed: String(localized: "passed", bundle: bundle)
        case .problem(let message): String(localized: "problem: \(message)", bundle: bundle)
        case .notChecked: String(localized: "not checked", bundle: bundle)
        case .unableToVerify: String(localized: "unable to verify", bundle: bundle)
        }
    }
}
