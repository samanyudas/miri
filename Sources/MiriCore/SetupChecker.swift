import Foundation

/// What the setup checker observed. `nil` means the value could not be read.
public struct SetupObservation: Equatable, Sendable {
    public var accessibilityTrusted: Bool
    /// `com.apple.spaces` `spans-displays`. `true` means **Displays have separate Spaces** is off.
    public var spansDisplays: Bool?
    /// `com.apple.WindowManager` `GloballyEnabled`.
    public var stageManager: Bool?
    /// `TrackpadThreeFingerHorizSwipeGesture`: 0 off, 1 swipe between pages, 2 swipe between full-screen apps.
    public var threeFingerSwipe: Int?
    /// `TrackpadFourFingerHorizSwipeGesture`: 0 off, 2 swipe between full-screen apps.
    public var fourFingerSwipe: Int?
    public var threeFingerDrag: Bool?
    public var runningBundleIdentifiers: Set<String>
    public var runningProcessNames: Set<String>

    public init(
        accessibilityTrusted: Bool, spansDisplays: Bool?, stageManager: Bool?, threeFingerSwipe: Int?,
        fourFingerSwipe: Int?, threeFingerDrag: Bool?, runningBundleIdentifiers: Set<String>,
        runningProcessNames: Set<String>
    ) {
        self.accessibilityTrusted = accessibilityTrusted
        self.spansDisplays = spansDisplays
        self.stageManager = stageManager
        self.threeFingerSwipe = threeFingerSwipe
        self.fourFingerSwipe = fourFingerSwipe
        self.threeFingerDrag = threeFingerDrag
        self.runningBundleIdentifiers = runningBundleIdentifiers
        self.runningProcessNames = runningProcessNames
    }
}

public enum SetupStatus: Equatable, Sendable {
    case passed
    /// A problem the user can fix. The text says what to change.
    case problem(String)
    /// Miri could not inspect the setting. The text gives manual instructions.
    case notChecked(String)
    /// Gesture conflict detection was unavailable. Miri offers a gesture test instead.
    case unableToVerify(String)
}

public struct SetupCheck: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case accessibility, separateSpaces, competingManagers, stageManager, fourFingerGesture, threeFingerGesture
    }

    public let id: Kind
    public let title: String
    public let status: SetupStatus
    /// When the check has a problem, management cannot start.
    public let blocksStart: Bool
    public let settingsURL: URL?

    public var isBlocking: Bool {
        if case .problem = status { blocksStart } else { false }
    }
}

public enum SetupChecker {
    /// Known window managers that fight Miri for window positions, by bundle identifier and by process name.
    public static let competingManagers: [(name: String, bundleIdentifiers: Set<String>, processNames: Set<String>)] = [
        ("Paneru", ["com.github.karinushka.paneru", "com.github.karinushka.paneru.launcher"], ["paneru"]),
        ("AeroSpace", ["bobko.aerospace"], ["AeroSpace"]),
        ("Amethyst", ["com.amethyst.Amethyst"], []),
        ("yabai", [], ["yabai"]),
    ]

    static let accessibilityURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    static let desktopURL = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")
    static let trackpadURL = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")

    public static func evaluate(_ observation: SetupObservation) -> [SetupCheck] {
        [
            SetupCheck(
                id: .accessibility, title: "Accessibility permission",
                status: observation.accessibilityTrusted
                    ? .passed
                    : .problem(
                        "Turn on Miri in System Settings > Privacy & Security > Accessibility. Miri needs it to move windows."
                    ),
                blocksStart: true, settingsURL: accessibilityURL),
            SetupCheck(
                id: .separateSpaces, title: "Displays have separate Spaces",
                status: spacesStatus(observation),
                blocksStart: true, settingsURL: desktopURL),
            SetupCheck(
                id: .competingManagers, title: "Other window managers",
                status: competingStatus(observation), blocksStart: true, settingsURL: nil),
            SetupCheck(
                id: .stageManager, title: "Stage Manager",
                status: stageManagerStatus(observation),
                blocksStart: false, settingsURL: desktopURL),
            SetupCheck(
                id: .fourFingerGesture, title: "Four-finger strip swipe",
                status: fourFingerStatus(observation),
                blocksStart: false, settingsURL: trackpadURL),
            SetupCheck(
                id: .threeFingerGesture, title: "Three-finger strip swipe",
                status: threeFingerStatus(observation), blocksStart: false, settingsURL: trackpadURL),
        ]
    }

    /// The names of running competing window managers.
    public static func runningCompetitors(_ observation: SetupObservation) -> [String] {
        competingManagers.filter {
            !$0.bundleIdentifiers.isDisjoint(with: observation.runningBundleIdentifiers)
                || !$0.processNames.isDisjoint(with: observation.runningProcessNames)
        }.map(\.name)
    }

    private static func competingStatus(_ observation: SetupObservation) -> SetupStatus {
        let running = runningCompetitors(observation)
        guard !running.isEmpty else { return .passed }
        let names = ListFormatter.localizedString(byJoining: running)
        return .problem("Quit \(names) before starting Miri. Miri leaves \(names)'s configuration untouched.")
    }

    private static func spacesStatus(_ observation: SetupObservation) -> SetupStatus {
        switch observation.spansDisplays {
        case false?: .passed
        case true?:
            .problem(
                "Turn on Displays have separate Spaces in System Settings > Desktop & Dock > Mission Control, then log out and back in."
            )
        case nil:
            .notChecked(
                "Open System Settings > Desktop & Dock > Mission Control and make sure Displays have separate Spaces is on."
            )
        }
    }

    private static func stageManagerStatus(_ observation: SetupObservation) -> SetupStatus {
        switch observation.stageManager {
        case false?: .passed
        case true?:
            .problem("Turn off Stage Manager in System Settings > Desktop & Dock. It rearranges windows.")
        case nil: .notChecked("Open System Settings > Desktop & Dock and make sure Stage Manager is off.")
        }
    }

    private static func fourFingerStatus(_ observation: SetupObservation) -> SetupStatus {
        switch observation.fourFingerSwipe {
        case 0?: .passed
        case 2?:
            .problem(
                "Four-finger swipes switch full-screen apps. Turn off Swipe between full-screen applications in System Settings > Trackpad > More Gestures, or set it to three fingers."
            )
        default: gestureUnverified(fingers: "four")
        }
    }

    private static func threeFingerStatus(_ observation: SetupObservation) -> SetupStatus {
        if observation.threeFingerDrag == true {
            return .problem(
                "Three Finger Drag is on. Turn it off in System Settings > Accessibility > Pointer Control > Trackpad Options, or use four fingers."
            )
        }
        switch observation.threeFingerSwipe {
        case 0? where observation.threeFingerDrag == false: return .passed
        case 1?:
            return .problem(
                "Three-finger swipes navigate between pages. Set Swipe between pages to two fingers in System Settings > Trackpad > More Gestures."
            )
        case 2?:
            return .problem(
                "Three-finger swipes switch full-screen apps. Set Swipe between full-screen applications to four fingers in System Settings > Trackpad > More Gestures."
            )
        default: return gestureUnverified(fingers: "three")
        }
    }

    private static func gestureUnverified(fingers: String) -> SetupStatus {
        .unableToVerify(
            "Miri could not read the macOS \(fingers)-finger swipe settings. A gesture test can confirm the swipe works."
        )
    }
}
