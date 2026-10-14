import AppKit
import ApplicationServices
import MiriCore

/// Moves stranded windows back into view through the Accessibility API, independently of the engine.
enum WindowRestorer {
    struct Summary: Codable, Equatable {
        var checked = 0
        var moved = 0
    }

    /// Each display's visible frame in Accessibility coordinates, with the main display first.
    static func displayFrames() -> [CGRect] {
        guard let main = NSScreen.screens.first else { return [] }
        return NSScreen.screens.map { screen in
            let frame = screen.visibleFrame
            return CGRect(x: frame.minX, y: main.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
        }
    }

    /// Recovers every stranded standard window of ordinary apps. `processes` limits recovery to those processes.
    @discardableResult
    static func recover(processes: Set<pid_t>? = nil) -> Summary {
        guard AXIsProcessTrusted() else { return Summary() }
        let displays = displayFrames()
        var summary = Summary()
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != getpid()
            && processes?.contains(app.processIdentifier) ?? true
        {
            for window in windows(of: app.processIdentifier) {
                guard let current = frame(of: window) else { continue }
                summary.checked += 1
                guard let target = WindowRecovery.target(for: current, displays: displays) else { continue }
                setFrame(target, of: window)
                summary.moved += 1
            }
        }
        return summary
    }

    /// The titles of every open window of ordinary apps, so diagnostics can remove them.
    static func openWindowTitles() -> [String] {
        guard AXIsProcessTrusted() else { return [] }
        return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.flatMap { app in
            let application = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(application, 0.25)
            let windows = attribute(kAXWindowsAttribute, of: application) as? [AXUIElement] ?? []
            return windows.compactMap { attribute(kAXTitleAttribute, of: $0) as? String }
        }
    }

    /// Standard windows that are neither minimized nor in native fullscreen.
    static func windows(of pid: pid_t) -> [AXUIElement] {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.25)
        guard let windows = attribute(kAXWindowsAttribute, of: application) as? [AXUIElement] else { return [] }
        return windows.filter { window in
            attribute(kAXSubroleAttribute, of: window) as? String == kAXStandardWindowSubrole
                && attribute(kAXMinimizedAttribute, of: window) as? Bool != true
                && attribute("AXFullScreen", of: window) as? Bool != true
        }
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard let position = attribute(kAXPositionAttribute, of: window), CFGetTypeID(position) == AXValueGetTypeID(),
            let extent = attribute(kAXSizeAttribute, of: window), CFGetTypeID(extent) == AXValueGetTypeID(),
            AXValueGetValue(position as! AXValue, .cgPoint, &origin),
            AXValueGetValue(extent as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// Sets size, then position, then size again, because an app may limit the size at the old position.
    static func setFrame(_ frame: CGRect, of window: AXUIElement) {
        var origin = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin), let extent = AXValueCreate(.cgSize, &size) else {
            return
        }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, extent)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, extent)
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}

/// Strands one window of a test fixture off-screen, recovers it, and reports the frames. It touches no other app.
enum RecoverySelftest {
    struct Report: Encodable {
        let schemaVersion = 1
        let trusted: Bool
        var original: CGRect?
        var stranded: CGRect?
        var strandedNeededRecovery: Bool?
        var recovered: CGRect?
        var recoveredIsReachable: Bool?
        var summary: WindowRestorer.Summary?
        var failure: String?
    }

    static func run(targetPid: pid_t) -> Report {
        var report = Report(trusted: AXIsProcessTrusted())
        guard report.trusted else { return report }
        let displays = WindowRestorer.displayFrames()
        guard let window = WindowRestorer.windows(of: targetPid).first,
            let original = WindowRestorer.frame(of: window)
        else {
            report.failure = "The fixture has no standard window."
            return report
        }
        report.original = original
        let farRight = displays.map(\.maxX).max() ?? 0
        WindowRestorer.setFrame(original.offsetBy(dx: farRight + 2000 - original.minX, dy: 0), of: window)
        report.stranded = WindowRestorer.frame(of: window)
        report.strandedNeededRecovery = report.stranded.map {
            WindowRecovery.target(for: $0, displays: displays) != nil
        }
        report.summary = WindowRestorer.recover(processes: [targetPid])
        report.recovered = WindowRestorer.frame(of: window)
        report.recoveredIsReachable = report.recovered.map { WindowRecovery.target(for: $0, displays: displays) == nil }
        return report
    }
}
