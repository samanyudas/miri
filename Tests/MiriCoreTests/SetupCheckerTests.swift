import Testing

@testable import MiriCore

struct SetupCheckerTests {
    private let ready = SetupObservation(
        accessibilityTrusted: true, spansDisplays: false, stageManager: false, threeFingerSwipe: 0,
        fourFingerSwipe: 0, threeFingerDrag: false, edgeTiling: false, menuBarTiling: false,
        optionDragTiling: false, runningBundleIdentifiers: ["com.apple.finder"],
        runningProcessNames: ["Finder"])

    private func status(_ kind: SetupCheck.Kind, _ observation: SetupObservation) -> SetupStatus? {
        SetupChecker.evaluate(observation).first { $0.id == kind }?.status
    }

    @Test func passesAReadyMac() {
        let checks = SetupChecker.evaluate(ready)
        #expect(checks.map(\.id) == SetupCheck.Kind.allCases)
        #expect(checks.allSatisfy { $0.status == .passed })
        #expect(!checks.contains { $0.isBlocking })
    }

    @Test func blocksStartForPermissionSpacesAndCompetitors() {
        var observation = ready
        observation.accessibilityTrusted = false
        observation.spansDisplays = true
        observation.runningProcessNames.insert("paneru")
        observation.runningBundleIdentifiers.insert("bobko.aerospace")
        let blocking = SetupChecker.evaluate(observation).filter(\.isBlocking).map(\.id)
        #expect(blocking == [.accessibility, .separateSpaces, .competingManagers])
        guard case .problem(let message) = status(.competingManagers, observation) else {
            Issue.record("Expected a competing manager problem")
            return
        }
        #expect(message.contains("Paneru") && message.contains("AeroSpace"))
        guard case .problem(let spaces) = status(.separateSpaces, observation) else {
            Issue.record("Expected a Spaces problem")
            return
        }
        #expect(spaces.contains("log out"))
    }

    @Test func namesTheMacOS27PermissionPane() {
        var observation = ready
        observation.accessibilityTrusted = false
        guard case .problem(let message) = status(.accessibility, observation) else {
            Issue.record("Expected an Accessibility problem")
            return
        }
        #expect(message.contains("System Settings > Privacy & Security > Device Control and Data Access"))
    }

    @Test func neverReportsAnUnreadableSettingAsPassed() {
        let unknown = SetupObservation(
            accessibilityTrusted: true, spansDisplays: nil, stageManager: nil, threeFingerSwipe: nil,
            fourFingerSwipe: nil, threeFingerDrag: nil, edgeTiling: nil, menuBarTiling: nil, optionDragTiling: nil,
            runningBundleIdentifiers: [], runningProcessNames: [])
        let checks = SetupChecker.evaluate(unknown)
        for kind in [SetupCheck.Kind.separateSpaces, .stageManager, .macOSTiling] {
            guard case .notChecked = checks.first(where: { $0.id == kind })?.status else {
                Issue.record("\(kind) should be Not checked")
                continue
            }
        }
        for kind in [SetupCheck.Kind.fourFingerGesture, .threeFingerGesture] {
            guard case .unableToVerify = checks.first(where: { $0.id == kind })?.status else {
                Issue.record("\(kind) should be Unable to verify")
                continue
            }
        }
        #expect(!checks.contains { $0.isBlocking })
    }

    @Test func aFourFingerValueThatThreeFingersOverrideIsNoConflict() {
        var observation = ready
        observation.threeFingerSwipe = 2
        observation.fourFingerSwipe = 2
        #expect(status(.fourFingerGesture, observation) == .passed)
        observation.threeFingerSwipe = 0
        #expect(status(.fourFingerGesture, observation) != .passed)
    }

    @Test func aFourFingerValueIsUnverifiedWhenTheThreeFingerValueIsUnreadable() {
        var observation = ready
        observation.threeFingerSwipe = nil
        observation.fourFingerSwipe = 2
        guard case .unableToVerify = status(.fourFingerGesture, observation) else {
            Issue.record("Expected Unable to verify")
            return
        }
    }

    @Test func reportsGestureConflicts() {
        var observation = ready
        observation.fourFingerSwipe = 2
        observation.threeFingerSwipe = 1
        guard case .problem = status(.fourFingerGesture, observation),
            case .problem(let pages) = status(.threeFingerGesture, observation)
        else {
            Issue.record("Expected gesture conflicts")
            return
        }
        #expect(pages.contains("Swipe between pages"))
        observation.threeFingerSwipe = 0
        observation.threeFingerDrag = true
        guard case .problem(let drag) = status(.threeFingerGesture, observation) else {
            Issue.record("Expected a Three Finger Drag conflict")
            return
        }
        #expect(drag.contains("Three Finger Drag"))
        #expect(SetupChecker.evaluate(observation).filter(\.isBlocking).isEmpty)
    }

    @Test func reportsEachMacOSTilingOptionThatIsOn() {
        var observation = ready
        observation.edgeTiling = true
        observation.optionDragTiling = true
        guard case .problem(let message) = status(.macOSTiling, observation) else {
            Issue.record("Expected a tiling conflict")
            return
        }
        #expect(message.contains("Drag windows to screen edges to tile"))
        #expect(message.contains("Hold ⌥ key while dragging windows to tile"))
        #expect(!message.contains("menu bar"))
        #expect(SetupChecker.evaluate(observation).filter(\.isBlocking).isEmpty)
        observation = ready
        observation.menuBarTiling = true
        guard case .problem(let menuBar) = status(.macOSTiling, observation) else {
            Issue.record("Expected a menu bar tiling conflict")
            return
        }
        #expect(menuBar.contains("Drag windows to menu bar to fill screen"))
    }

    @Test func aTilingOptionThatIsOnOutranksOneThatCannotBeRead() {
        var observation = ready
        observation.edgeTiling = nil
        observation.menuBarTiling = true
        guard case .problem = status(.macOSTiling, observation) else {
            Issue.record("Expected a tiling conflict")
            return
        }
        observation.menuBarTiling = false
        guard case .notChecked(let manual) = status(.macOSTiling, observation) else {
            Issue.record("Expected Not checked")
            return
        }
        #expect(manual.contains("Drag windows to screen edges to tile"))
    }
}
