import AppKit
import ApplicationServices
import Darwin
import MiriCore

/// Reads the macOS state the setup checker needs. It only reads preferences and never writes them.
enum SetupProbe {
    static func observe() -> SetupObservation {
        let trackpad = "com.apple.AppleMultitouchTrackpad"
        let workspace = NSWorkspace.shared
        return SetupObservation(
            accessibilityTrusted: AXIsProcessTrusted(),
            spansDisplays: preference("spans-displays", domain: "com.apple.spaces").map(\.boolValue)
                ?? (domainExists("com.apple.spaces") ? false : nil),
            stageManager: preference("GloballyEnabled", domain: "com.apple.WindowManager").map(\.boolValue),
            threeFingerSwipe: preference("TrackpadThreeFingerHorizSwipeGesture", domain: trackpad)?.intValue,
            fourFingerSwipe: preference("TrackpadFourFingerHorizSwipeGesture", domain: trackpad)?.intValue,
            threeFingerDrag: preference("TrackpadThreeFingerDrag", domain: trackpad).map(\.boolValue),
            runningBundleIdentifiers: Set(workspace.runningApplications.compactMap(\.bundleIdentifier)),
            runningProcessNames: processNames())
    }

    private static func preference(_ key: String, domain: String) -> NSNumber? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber
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
