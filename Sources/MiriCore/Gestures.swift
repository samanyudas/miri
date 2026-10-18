import Foundation

/// The strip swipe the user selected, stored in `[miri].strip_gesture`. Five fingers is not a v1 choice.
public enum StripGesture: String, CaseIterable, Sendable {
    case off, three, four

    public var fingers: GestureFingers? {
        switch self {
        case .off: nil
        case .three: .three
        case .four: .four
        }
    }
}

/// A finger count the strip swipe can use. The raw value is the engine's `[swipe.gesture].fingers_count`.
public enum GestureFingers: Int, Codable, Sendable {
    case three = 3
    case four = 4

    /// The setup check that reports macOS gestures clashing with this finger count.
    public var setupCheck: SetupCheck.Kind {
        switch self {
        case .three: .threeFingerGesture
        case .four: .fourFingerGesture
        }
    }
}

/// The macOS trackpad settings that decide whether a strip swipe clashes with a macOS gesture. `nil` is unreadable.
public struct GestureSettingsSnapshot: Codable, Equatable, Sendable {
    public var threeFingerSwipe: Int?
    public var fourFingerSwipe: Int?
    public var threeFingerDrag: Bool?

    public init(threeFingerSwipe: Int?, fourFingerSwipe: Int?, threeFingerDrag: Bool?) {
        self.threeFingerSwipe = threeFingerSwipe
        self.fourFingerSwipe = fourFingerSwipe
        self.threeFingerDrag = threeFingerDrag
    }

    public init(_ observation: SetupObservation) {
        self.init(
            threeFingerSwipe: observation.threeFingerSwipe, fourFingerSwipe: observation.fourFingerSwipe,
            threeFingerDrag: observation.threeFingerDrag)
    }

    /// Whether a setting readable in both snapshots differs. A setting that cannot be read in either one is not
    /// compared, because Miri cannot see whether it changed.
    func differs(from other: Self) -> Bool {
        func changed<Value: Equatable>(_ a: Value?, _ b: Value?) -> Bool {
            guard let a, let b else { return false }
            return a != b
        }
        return changed(threeFingerSwipe, other.threeFingerSwipe) || changed(fourFingerSwipe, other.fourFingerSwipe)
            || changed(threeFingerDrag, other.threeFingerDrag)
    }
}

/// What a gesture test result depends on. A change to any of it requires a new test.
public struct GestureEnvironment: Codable, Equatable, Sendable {
    public var macOSVersion: String
    public var engineRevision: String
    public var gestureSettings: GestureSettingsSnapshot

    public init(macOSVersion: String, engineRevision: String, gestureSettings: GestureSettingsSnapshot) {
        self.macOSVersion = macOSVersion
        self.engineRevision = engineRevision
        self.gestureSettings = gestureSettings
    }
}

/// A gesture test the user passed and confirmed: **Verified by user test**. The app keeps it outside the
/// configuration file, so editing the file cannot mark a gesture as tested.
public struct GestureVerification: Codable, Equatable, Sendable {
    public var fingers: GestureFingers
    public var reversed: Bool
    public var environment: GestureEnvironment
    public var date: Date

    public init(fingers: GestureFingers, reversed: Bool, environment: GestureEnvironment, date: Date) {
        self.fingers = fingers
        self.reversed = reversed
        self.environment = environment
        self.date = date
    }
}

/// Whether the strip swipe is on, and why not. Automatic detection only finds conflicts, and only a user test
/// that matches the current setup turns the swipe on.
public enum GestureState: Equatable, Sendable {
    public enum TestReason: Equatable, Sendable {
        case neverTested, fingersChanged, directionChanged, macOSChanged, engineChanged, gestureSettingsChanged
    }

    case off
    /// macOS uses the selected swipe. The text says which setting to change.
    case conflict(String)
    /// The swipe stays off until a new test passes. `detectionUnavailable` means Miri could not read the macOS
    /// settings, so it shows **Unable to verify**.
    case needsTest(TestReason, detectionUnavailable: Bool)
    case enabled(verifiedAt: Date)

    /// `conflict` is the setup check status for the selected finger count.
    public static func evaluate(
        preference: StripGesture, reversed: Bool, verification: GestureVerification?,
        environment: GestureEnvironment, conflict: SetupStatus
    ) -> GestureState {
        guard let fingers = preference.fingers else { return .off }
        if case .problem(let message) = conflict { return .conflict(message) }
        let unavailable = if case .unableToVerify = conflict { true } else { false }
        guard let verification else { return .needsTest(.neverTested, detectionUnavailable: unavailable) }
        let tested = verification.environment
        let reason: TestReason? =
            if verification.fingers != fingers {
                .fingersChanged
            } else if verification.reversed != reversed {
                .directionChanged
            } else if tested.macOSVersion != environment.macOSVersion {
                .macOSChanged
            } else if tested.engineRevision != environment.engineRevision {
                .engineChanged
            } else if tested.gestureSettings.differs(from: environment.gestureSettings) {
                .gestureSettingsChanged
            } else {
                nil
            }
        if let reason { return .needsTest(reason, detectionUnavailable: unavailable) }
        return .enabled(verifiedAt: verification.date)
    }

    public var isEnabled: Bool {
        if case .enabled = self { true } else { false }
    }
}

/// Which way the strip moved between two engine state readings.
public enum StripMovement: Sendable {
    case left, right

    /// The movement of the active virtual workspace's strip from `before` to `after`, or `nil` when it did not
    /// slide. A swipe moves windows without resizing them. A resize also pushes its neighbors sideways, so any width
    /// change means the pair does not count.
    public static func between(_ before: EngineStateSnapshot, _ after: EngineStateSnapshot) -> StripMovement? {
        guard before.active == after.active else { return nil }
        let earlier = Dictionary(
            before.activeWindows.compactMap { window in window.frame.map { (window.windowId, $0) } },
            uniquingKeysWith: { first, _ in first })
        let pairs = after.activeWindows.compactMap { window in
            window.frame.flatMap { frame in earlier[window.windowId].map { (before: $0, after: frame) } }
        }
        guard pairs.allSatisfy({ $0.before.width == $0.after.width }),
            let moved = pairs.first(where: { $0.before.x != $0.after.x })
        else { return nil }
        return moved.after.x < moved.before.x ? .left : .right
    }
}

/// The parts of `miri-engine query state --json` that the gesture test reads.
public struct EngineStateSnapshot: Decodable, Equatable, Sendable {
    public struct Active: Decodable, Equatable, Sendable {
        public var nativeWorkspaceId: UInt64?
        public var virtualWorkspaceNumber: UInt32?
    }

    public struct Row: Decodable, Equatable, Sendable {
        public var number: UInt32
        public var nativeWorkspaceId: UInt64
        public var active: Bool
        public var windows: [Window]
    }

    public struct Window: Decodable, Equatable, Sendable {
        public var windowId: Int32
        public var frame: Frame?
    }

    public struct Frame: Decodable, Equatable, Sendable {
        public var x: Int
        public var y: Int
        public var width: Int
        public var height: Int
    }

    public var active: Active
    public var virtualWorkspaces: [Row]

    public init(json: Data) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self = try decoder.decode(Self.self, from: json)
    }

    /// The windows of the virtual workspace the engine's swipe moves: the active one on the focused display.
    var activeWindows: [Window] {
        virtualWorkspaces.filter { row in
            row.nativeWorkspaceId == active.nativeWorkspaceId && row.number == active.virtualWorkspaceNumber
        }.flatMap(\.windows)
    }
}
