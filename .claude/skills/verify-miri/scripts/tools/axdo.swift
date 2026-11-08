// Reads and presses Accessibility elements of one app, and lists its on-screen windows.
// Usage:
//   axdo <pid> dump                  every element of every window: role, then title | description | value | help
//   axdo <pid> status                the Settings status text in each window (General or Gestures)
//   axdo <pid> press <title>...      presses each button, tab, radio button, or switch with that title, description, or help
//                                    text, in order. When several match, it presses the first.
//   axdo <pid> windows               the CoreGraphics window number, layer, bounds, and title of each window
//   axdo frontmost                   the process ID of the frontmost app
//   axdo builtin-display             the display ID of the built-in display, or nothing when none is active
//   axdo hide <bundle id>            hides each running app with that bundle ID, as Command-H does, and prints one
//                                    "<pid> hidden-before|shown-before <name>" line for each
//   axdo unhide <pid>...             shows each app again
// Exit status: 0 on success, 1 when a title has no element or a press fails, 2 on a usage error.
import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func text(_ element: AXUIElement, _ name: String) -> String? { attribute(element, name) as? String }

func walk(_ element: AXUIElement, _ depth: Int = 0, _ visit: (AXUIElement, Int) -> Void) {
    visit(element, depth)
    for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { walk(child, depth + 1, visit) }
}

func usage() -> Never {
    FileHandle.standardError.write(Data(
        "usage: axdo <pid> dump|status|press <title>...|windows, or axdo frontmost|builtin-display|hide <bundle id>|unhide <pid>...\n".utf8))
    exit(2)
}

let arguments = CommandLine.arguments
if arguments.count == 2, arguments[1] == "frontmost" {
    print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
    exit(0)
}
if arguments.count == 2, arguments[1] == "builtin-display" {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    CGGetActiveDisplayList(16, &ids, &count)
    if let id = ids.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }) { print(id) }
    exit(0)
}
if arguments.count == 3, arguments[1] == "hide" {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: arguments[2]) {
        // The engine learns of a hide only from the hide event, so it still tiles an app that was hidden before it
        // started. Showing such an app first makes the next hide send that event.
        let wasHidden = app.isHidden
        if wasHidden {
            _ = app.unhide()
            let deadline = Date().addingTimeInterval(2)
            while app.isHidden, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        }
        // hide() returns false on macOS 27 even when the app hides, so its result says nothing.
        _ = app.hide()
        print("\(app.processIdentifier) \(wasHidden ? "hidden-before" : "shown-before") \(app.localizedName ?? arguments[2])")
    }
    exit(0)
}
if arguments.count >= 3, arguments[1] == "unhide" {
    for pid in arguments.dropFirst(2) {
        guard let pid = Int32(pid), let app = NSRunningApplication(processIdentifier: pid) else { continue }
        _ = app.unhide()
    }
    exit(0)
}
guard arguments.count >= 3, let pid = Int32(arguments[1]) else { usage() }
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 2)
let windows = (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
let pressableRoles: Set<String> = [
    kAXButtonRole as String, kAXRadioButtonRole as String, kAXCheckBoxRole as String, "AXTab",
]

switch arguments[2] {
case "dump":
    for window in windows {
        walk(window) { element, depth in
            let role = text(element, kAXRoleAttribute) ?? "?"
            let parts = [text(element, kAXTitleAttribute), text(element, kAXDescriptionAttribute),
                         attribute(element, kAXValueAttribute).map { "\($0)" }, text(element, kAXHelpAttribute).map { "help: \($0)" }]
            let label = parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
            print(String(repeating: "  ", count: depth) + role + " " + label)
        }
    }
case "status":
    for window in windows {
        // Settings marks its status text with this identifier. Older builds put it after a "Status" label.
        var marked: String?
        var texts: [String] = []
        walk(window) { element, _ in
            if marked == nil, text(element, "AXIdentifier") == "miri.status" {
                marked = attribute(element, kAXValueAttribute) as? String
            }
            if text(element, kAXRoleAttribute) == kAXStaticTextRole as String,
                let value = attribute(element, kAXValueAttribute) as? String
            {
                texts.append(value)
            }
        }
        if let marked {
            print(marked)
        } else if let index = texts.firstIndex(of: "Status"), index + 1 < texts.count {
            print(texts[index + 1])
        }
    }
case "press":
    guard arguments.count >= 4 else { usage() }
    for title in arguments.dropFirst(3) {
        // Walk again before each press: the previous press can show another tab, sheet, or alert.
        var found: [String: AXUIElement] = [:]
        for window in (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [] {
            walk(window) { element, _ in
                guard pressableRoles.contains(text(element, kAXRoleAttribute) ?? "") else { return }
                // A row's buttons can share a title. Their help text, such as "Add a shortcut for Focus column right", tells them apart.
                for name in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
                    if let key = text(element, name), !key.isEmpty, found[key] == nil { found[key] = element }
                }
            }
        }
        guard let element = found[title] else {
            print("no element titled \(title); have \(found.keys.sorted())")
            exit(1)
        }
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        print("pressed \(title) at \(Date().timeIntervalSince1970) -> AXError \(result.rawValue)")
        if result != .success { exit(1) }
    }
case "windows":
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for info in list where (info[kCGWindowOwnerPID as String] as? Int32) == pid {
        let number = info[kCGWindowNumber as String] as? Int ?? 0
        let layer = info[kCGWindowLayer as String] as? Int ?? 0
        let bounds = info[kCGWindowBounds as String] as? [String: Double] ?? [:]
        let frame = ["X", "Y", "Width", "Height"].map { Int(bounds[$0] ?? 0) }
        let title = info[kCGWindowName as String] as? String ?? ""
        print("\(number) layer=\(layer) frame=\(frame) title=\(title)")
    }
default:
    usage()
}
