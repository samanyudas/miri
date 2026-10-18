import Testing

@testable import MiriCore

struct SetupCheckerTests {
    private let ready = SetupObservation(
        accessibilityTrusted: true, spansDisplays: false, stageManager: false, threeFingerSwipe: 0,
        fourFingerSwipe: 0, threeFingerDrag: false, runningBundleIdentifiers: ["com.apple.finder"],
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

    @Test func neverReportsAnUnreadableSettingAsPassed() {
        let unknown = SetupObservation(
            accessibilityTrusted: true, spansDisplays: nil, stageManager: nil, threeFingerSwipe: nil,
            fourFingerSwipe: nil, threeFingerDrag: nil, runningBundleIdentifiers: [], runningProcessNames: [])
        let checks = SetupChecker.evaluate(unknown)
        for kind in [SetupCheck.Kind.separateSpaces, .stageManager] {
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
}
