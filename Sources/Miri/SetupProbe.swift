import AppKit
import ApplicationServices
import Darwin
import MiriCore

/// Reads macOS permissions and preferences for setup checks, and hosts small AppKit system helpers.
/// It never writes preferences.
enum SetupProbe {
    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

    /// Reads Screen Recording permission without prompting. Only turning a switch on prompts.
    static var screenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Prompts macOS for Screen Recording permission when the user turns on a switch that needs it.
    static func requestScreenRecording() -> Bool { CGRequestScreenCaptureAccess() }

    /// Converts an AppKit (bottom-left origin) rectangle to Accessibility (top-left of main display) coordinates.
    static func axFrame(for frame: CGRect, mainMaxY: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: mainMaxY - frame.maxY, width: frame.width, height: frame.height)
    }

    /// Reveals `url` in Finder and brings Finder to the front even when invoked from the menu bar while inactive.
    static func revealInFinder(_ url: URL) {
        let reveal: @MainActor () -> Void = {
            NSApp.yieldActivation(toApplicationWithBundleIdentifier: "com.apple.finder")
            NSWorkspace.shared.activateFileViewerSelecting([url])
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
                .first?.activate(from: .current, options: [])
        }
        if NSApp.isActive {
            reveal()
            return
        }
        // Clicking a menu bar item while another app is frontmost leaves Miri inactive, so Finder cannot take focus
        // under cooperative activation. Activate Miri first, then hand activation to Finder once Miri is active.
        var revealed = false
        nonisolated(unsafe) var observer: NSObjectProtocol?
        let finish: @MainActor () -> Void = {
            guard !revealed else { return }
            revealed = true
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            reveal()
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: NSApp, queue: .main
        ) { _ in
            MainActor.assumeIsolated { finish() }
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { finish() }
    }

    static func observe() -> SetupObservation {
        let trackpad = "com.apple.AppleMultitouchTrackpad"
        let workspace = NSWorkspace.shared
        // Reloads the cached trackpad values, so a change made in System Settings while Miri runs is seen.
        // It writes nothing, because Miri never sets a value in that domain.
        CFPreferencesAppSynchronize(trackpad as CFString)
        return SetupObservation(
            accessibilityTrusted: AXIsProcessTrusted(),
            spansDisplays: preference("spans-displays", domain: "com.apple.spaces").map(\.boolValue)
                ?? (domainExists("com.apple.spaces") ? false : nil),
            stageManager: preference("GloballyEnabled", domain: "com.apple.WindowManager").map(\.boolValue),
            threeFingerSwipe: preference("TrackpadThreeFingerHorizSwipeGesture", domain: trackpad)?.intValue,
            fourFingerSwipe: preference("TrackpadFourFingerHorizSwipeGesture", domain: trackpad)?.intValue,
            threeFingerDrag: preference("TrackpadThreeFingerDrag", domain: trackpad).map(\.boolValue),
            edgeTiling: tilingPreference("EnableTilingByEdgeDrag"),
            menuBarTiling: tilingPreference("EnableTopTilingByEdgeDrag"),
            optionDragTiling: tilingPreference("EnableTilingOptionAccelerator"),
            runningBundleIdentifiers: Set(workspace.runningApplications.compactMap(\.bundleIdentifier)),
            runningProcessNames: processNames(),
            macOSMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    private static func preference(_ key: String, domain: String) -> NSNumber? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber
    }

    /// macOS turns each tiling option on by default and stores a value only after the user changes it,
    /// so an absent value means on.
    private static func tilingPreference(_ key: String) -> Bool {
        preference(key, domain: "com.apple.WindowManager")?.boolValue ?? true
    }

    /// `spans-displays` is absent until the user changes the setting, and absent means separate Spaces are on.
    private static func domainExists(_ domain: String) -> Bool {
        (CFPreferencesCopyKeyList(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String])
            .map { !$0.isEmpty } ?? false
    }

    /// The names of the current user's processes, so command-line window managers are found too.
    private static func processNames() -> Set<String> {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var names = Set<String>()
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        for pid in pids.prefix(Int(max(0, filled))) where pid > 0 && pid != getpid() {
            let length = Int(proc_name(pid, &buffer, UInt32(buffer.count)))
            guard length > 0 else { continue }
            names.insert(String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self))
        }
        return names
    }
}
