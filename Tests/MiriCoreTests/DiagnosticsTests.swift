import Testing

@testable import MiriCore

struct RedactorTests {
    let redactor = Redactor(
        homeDirectory: "/Users/sam", userNames: ["sam", "Samanyu Das"],
        sensitiveStrings: ["Quarterly report.numbers", "ok"])

    @Test func removesTitlesPathsQuotesAndUserNames() {
        let log = """
            \u{1B}[32m INFO\u{1B}[0m focused window Quarterly report.numbers on display 2
            watching the config '/Users/sam/Library/Application Support/Miri/config.toml': gone
            opened /Users/sam/Documents/plan.pages and /Volumes/Backup/x.txt
            window title: "Inbox - sam@example.com"
            user sam logged in as Samanyu Das, samantha unchanged
            engine at /Applications/Miri.app/Contents/Helpers/miri-engine ok
            """
        let redacted = redactor.redact(log)
        #expect(
            redacted == """
                 INFO focused window <title> on display 2
                watching the config '<redacted>': gone
                opened <path> and <path>
                window title: "<redacted>"
                user <user> logged in as <user>, samantha unchanged
                engine at /Applications/Miri.app/Contents/Helpers/miri-engine ok
                """)
    }

    @Test func redactsAPathWithSpacesOutsideQuotes() {
        #expect(redactor.redact("saved /Users/sam/Desktop/a.txt") == "saved <path>")
        #expect(!redactor.redact("dir /Users/other/Secret/file").contains("Secret"))
    }
}

struct DiagnosticsReportTests {
    @Test func rendersEveryRequiredSectionWithoutRawConfiguration() {
        let report = DiagnosticsReport(
            appVersion: "0.0.1 (1)", engineRevision: "9ca903c", macOSVersion: "27.0", architecture: "arm64",
            displays: [
                .init(width: 2560, height: 1440, scale: 2, x: 0, y: 0, isMain: true),
                .init(width: 1470, height: 956, scale: 2, x: 251, y: -956, isMain: false),
            ],
            engineState: .restarting(crashes: 2),
            setupChecks: SetupChecker.evaluate(
                SetupObservation(
                    accessibilityTrusted: true, spansDisplays: false, stageManager: nil, threeFingerSwipe: 0,
                    fourFingerSwipe: 2, threeFingerDrag: false, edgeTiling: false, menuBarTiling: false,
                    optionDragTiling: false, runningBundleIdentifiers: [], runningProcessNames: [])),
            configurationIssue: .invalidTOML(TOMLError(line: 4, message: "Expected a value.")),
            log: "open /Users/sam/Documents/secret.txt\n")
        let text = report.rendered(with: Redactor(homeDirectory: "/Users/sam", userNames: ["sam"]))
        #expect(text.contains("- Miri: 0.0.1 (1)\n- Engine: 9ca903c\n- macOS: 27.0 (arm64)\n"))
        #expect(text.contains("- Engine status: restarting after 2 crashes\n"))
        #expect(text.contains("Line 4: Expected a value."))
        #expect(text.contains("- Display 1 (main): 2560 x 1440 points at 2x, origin (0, 0)\n"))
        #expect(text.contains("- Display 2: 1470 x 956 points at 2x, origin (251, -956)\n"))
        #expect(text.contains("- Accessibility permission: passed\n"))
        #expect(text.contains("- Stage Manager: not checked\n"))
        #expect(text.contains("- Four-finger strip swipe: problem: "))
        #expect(text.contains("```\nopen <path>\n```\n"))
        #expect(!text.contains("secret") && !text.contains("sam"))
    }
}
