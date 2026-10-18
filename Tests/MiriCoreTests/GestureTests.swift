import Foundation
import Testing

@testable import MiriCore

struct GestureStateTests {
    private static let tested = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let settings = GestureSettingsSnapshot(
        threeFingerSwipe: 2, fourFingerSwipe: 0, threeFingerDrag: false)
    private static let environment = GestureEnvironment(
        macOSVersion: "Version 27.0 (Build 27A100)", engineRevision: "a15682f", gestureSettings: settings)
    private static let fourFingers = GestureVerification(
        fingers: .four, reversed: false, environment: environment, date: tested)
    private static let unreadable = SetupStatus.unableToVerify("Miri could not read the macOS settings.")

    private func state(
        _ preference: StripGesture = .four, reversed: Bool = false,
        verification: GestureVerification? = fourFingers, environment: GestureEnvironment = environment,
        conflict: SetupStatus = .passed
    ) -> GestureState {
        GestureState.evaluate(
            preference: preference, reversed: reversed, verification: verification, environment: environment,
            conflict: conflict)
    }

    private func environment(
        macOS: String = environment.macOSVersion, engine: String = environment.engineRevision,
        _ change: (inout GestureSettingsSnapshot) -> Void = { _ in }
    ) -> GestureEnvironment {
        var settings = Self.settings
        change(&settings)
        return GestureEnvironment(macOSVersion: macOS, engineRevision: engine, gestureSettings: settings)
    }

    @Test func aNewSetupIsOff() {
        #expect(MiriSettings().stripGesture == .off)
        #expect(state(.off, verification: nil) == .off)
    }

    @Test func offStaysOffWhateverElseHolds() {
        #expect(state(.off) == .off)
        #expect(state(.off, conflict: .problem("Four-finger swipes switch full-screen apps.")) == .off)
    }

    @Test func aMatchingUserTestWithoutAConflictTurnsTheSwipeOn() {
        #expect(state() == .enabled(verifiedAt: Self.tested))
    }

    @Test func aMatchingUserTestTurnsTheSwipeOnWhenDetectionIsUnavailable() {
        #expect(state(conflict: Self.unreadable) == .enabled(verifiedAt: Self.tested))
    }

    @Test func untestedSwipesStayOffAndSayWhetherDetectionWorked() {
        #expect(state(verification: nil) == .needsTest(.neverTested, detectionUnavailable: false))
        #expect(
            state(verification: nil, conflict: Self.unreadable) == .needsTest(.neverTested, detectionUnavailable: true))
    }

    @Test func aConfirmedConflictBlocksEvenAPassedUserTest() {
        let conflict = SetupStatus.problem("Four-finger swipes switch full-screen apps.")
        #expect(state(conflict: conflict) == .conflict("Four-finger swipes switch full-screen apps."))
        #expect(
            state(verification: nil, conflict: conflict) == .conflict("Four-finger swipes switch full-screen apps."))
    }

    @Test func changingTheFingerCountOrDirectionNeedsANewTest() {
        #expect(state(.three) == .needsTest(.fingersChanged, detectionUnavailable: false))
        #expect(state(reversed: true) == .needsTest(.directionChanged, detectionUnavailable: false))
        let reversed = GestureVerification(
            fingers: .four, reversed: true, environment: Self.environment, date: Self.tested)
        #expect(state(reversed: true, verification: reversed) == .enabled(verifiedAt: Self.tested))
    }

    @Test func upgradingMacOSOrTheEngineNeedsANewTest() {
        #expect(
            state(environment: environment(macOS: "Version 27.1 (Build 27B50)"))
                == .needsTest(.macOSChanged, detectionUnavailable: false))
        #expect(
            state(environment: environment(engine: "b2c3d4e"))
                == .needsTest(.engineChanged, detectionUnavailable: false))
    }

    @Test func aDetectedMacOSGestureChangeNeedsANewTest() {
        #expect(
            state(environment: environment { $0.fourFingerSwipe = 2 }, conflict: .problem("switches apps"))
                == .conflict("switches apps"))
        #expect(
            state(environment: environment { $0.threeFingerSwipe = 0 })
                == .needsTest(.gestureSettingsChanged, detectionUnavailable: false))
        #expect(
            state(environment: environment { $0.threeFingerDrag = true })
                == .needsTest(.gestureSettingsChanged, detectionUnavailable: false))
    }

    @Test func aSettingMiriCannotReadIsNotReportedAsChanged() {
        let unreadableNow = environment {
            $0.threeFingerSwipe = nil
            $0.threeFingerDrag = nil
        }
        #expect(state(environment: unreadableNow, conflict: Self.unreadable) == .enabled(verifiedAt: Self.tested))
        let unreadableAtTest = GestureVerification(
            fingers: .four, reversed: false,
            environment: GestureEnvironment(
                macOSVersion: Self.environment.macOSVersion, engineRevision: Self.environment.engineRevision,
                gestureSettings: GestureSettingsSnapshot(
                    threeFingerSwipe: nil, fourFingerSwipe: nil, threeFingerDrag: nil)
            ), date: Self.tested)
        #expect(state(verification: unreadableAtTest) == .enabled(verifiedAt: Self.tested))
    }

    @Test func eachFingerCountUsesItsOwnSetupCheck() {
        let observation = SetupObservation(
            accessibilityTrusted: true, spansDisplays: false, stageManager: false, threeFingerSwipe: 1,
            fourFingerSwipe: 0, threeFingerDrag: false, runningBundleIdentifiers: [], runningProcessNames: [])
        let checks = SetupChecker.evaluate(observation)
        let three = checks.first { $0.id == GestureFingers.three.setupCheck }?.status
        let four = checks.first { $0.id == GestureFingers.four.setupCheck }?.status
        guard case .problem(let pages) = three else {
            Issue.record("Expected a three-finger conflict, got \(String(describing: three))")
            return
        }
        #expect(pages.contains("Swipe between pages"))
        #expect(four == .passed)
    }
}

struct GestureVerificationTests {
    @Test func roundTripsThroughJSON() throws {
        let verification = GestureVerification(
            fingers: .four, reversed: true,
            environment: GestureEnvironment(
                macOSVersion: "Version 27.0 (Build 27A100)", engineRevision: "a15682f",
                gestureSettings: GestureSettingsSnapshot(
                    threeFingerSwipe: 2, fourFingerSwipe: nil, threeFingerDrag: false)
            ),
            date: Date(timeIntervalSinceReferenceDate: 0))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(verification)
        #expect(
            String(decoding: data, as: UTF8.self)
                == #"{"date":0,"environment":{"engineRevision":"a15682f","gestureSettings":{"threeFingerDrag":false,"threeFingerSwipe":2},"macOSVersion":"Version 27.0 (Build 27A100)"},"fingers":4,"reversed":true}"#
        )
        #expect(try JSONDecoder().decode(GestureVerification.self, from: data) == verification)
    }
}

struct StripMovementTests {
    /// A `miri-engine query state --json` document with one window per entry on the active row of workspace 7.
    private func snapshot(_ windows: [(id: Int, x: Int, width: Int)], activeRow: Int = 1) throws -> EngineStateSnapshot
    {
        let rows = windows.map { window in
            """
            {"window_id":\(window.id),"bundle_id":"com.apple.TextEdit","app_name":"TextEdit","title":"Notes",\
            "focused":false,"floating":false,"display_id":1,\
            "frame":{"x":\(window.x),"y":33,"width":\(window.width),"height":800},"visible":true}
            """
        }.joined(separator: ",")
        let json = """
            {"version":1,"timestamp":1760000000,\
            "active":{"display_id":1,"native_workspace_id":7,"virtual_workspace_number":\(activeRow),\
            "focused_window_id":null,"focused_bundle_id":null,"focused_app_name":null,"focused_window_title":null},\
            "virtual_workspaces":[\
            {"number":1,"native_workspace_id":7,"active":\(activeRow == 1),"windows":[\(rows)]},\
            {"number":2,"native_workspace_id":7,"active":\(activeRow == 2),"windows":[]}]}
            """
        return try EngineStateSnapshot(json: Data(json.utf8))
    }

    @Test func seesTheStripMoveLeftAndRight() throws {
        let start = try snapshot([(1, 8, 600), (2, 616, 600)])
        let left = try snapshot([(1, -120, 600), (2, 488, 600)])
        #expect(StripMovement.between(start, left) == .left)
        #expect(StripMovement.between(left, start) == .right)
    }

    @Test func ignoresAStillStripAResizeThatPushesNeighborsAndAnotherWorkspace() throws {
        let start = try snapshot([(1, 8, 600), (2, 616, 600)])
        #expect(StripMovement.between(start, start) == nil)
        let resized = try snapshot([(1, 8, 700), (2, 716, 600)])
        #expect(StripMovement.between(start, resized) == nil)
        let grownOnly = try snapshot([(1, 8, 700), (2, 616, 600)])
        #expect(StripMovement.between(start, grownOnly) == nil)
        let otherRow = try snapshot([(1, -120, 600), (2, 488, 600)], activeRow: 2)
        #expect(StripMovement.between(start, otherRow) == nil)
    }

    @Test func ignoresWindowsThatAppearOrHaveNoFrame() throws {
        let start = try snapshot([(1, 8, 600)])
        let added = try snapshot([(1, 8, 600), (2, 616, 600)])
        #expect(StripMovement.between(start, added) == nil)
        let noFrame = try EngineStateSnapshot(
            json: Data(
                #"{"active":{"native_workspace_id":7,"virtual_workspace_number":1},"virtual_workspaces":[{"number":1,"native_workspace_id":7,"active":true,"windows":[{"window_id":1,"frame":null}]}]}"#
                    .utf8))
        #expect(StripMovement.between(start, noFrame) == nil)
    }
}
