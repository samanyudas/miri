// Reads and presses Accessibility elements of one app, and lists its on-screen windows.
// Usage:
//   axdo <pid> dump                  every element of every window: role, then title | description | value
//   axdo <pid> status                the text after the "Status" label in each window (Settings > General)
//   axdo <pid> press <title>...      presses each button, tab, or radio button with that title, in order
//   axdo <pid> windows               the CoreGraphics window number, layer, bounds, and title of each window
//   axdo frontmost                   the process ID of the frontmost app
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
    FileHandle.standardError.write(Data("usage: axdo <pid> dump|status|press <title>...|windows, or axdo frontmost\n".utf8))
    exit(2)
}

let arguments = CommandLine.arguments
if arguments.count == 2, arguments[1] == "frontmost" {
    print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
    exit(0)
}
guard arguments.count >= 3, let pid = Int32(arguments[1]) else { usage() }
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 2)
let windows = (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
let pressableRoles: Set<String> = [kAXButtonRole as String, kAXRadioButtonRole as String, "AXTab"]

switch arguments[2] {
case "dump":
    for window in windows {
        walk(window) { element, depth in
            let role = text(element, kAXRoleAttribute) ?? "?"
            let parts = [text(element, kAXTitleAttribute), text(element, kAXDescriptionAttribute),
                         attribute(element, kAXValueAttribute).map { "\($0)" }]
            let label = parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
            print(String(repeating: "  ", count: depth) + role + " " + label)
        }
    }
case "status":
    for window in windows {
        var texts: [String] = []
        walk(window) { element, _ in
            if text(element, kAXRoleAttribute) == kAXStaticTextRole as String,
                let value = attribute(element, kAXValueAttribute) as? String
            {
                texts.append(value)
            }
        }
        if let index = texts.firstIndex(of: "Status"), index + 1 < texts.count { print(texts[index + 1]) }
    }
case "press":
    guard arguments.count >= 4 else { usage() }
    var found: [String: AXUIElement] = [:]
    for window in windows {
        walk(window) { element, _ in
            guard pressableRoles.contains(text(element, kAXRoleAttribute) ?? "") else { return }
            let title = text(element, kAXTitleAttribute) ?? text(element, kAXDescriptionAttribute) ?? ""
            if !title.isEmpty, found[title] == nil { found[title] = element }
        }
    }
    for title in arguments.dropFirst(3) {
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
