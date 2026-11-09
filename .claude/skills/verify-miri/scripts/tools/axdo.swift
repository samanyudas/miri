// Reads and presses Accessibility elements of one app, and lists its on-screen windows.
// Usage:
//   axdo <pid> dump                  every element of every window: role, then title | description | value | help
//   axdo <pid> status                the Settings status text in each window (General or Gestures)
//   axdo <pid> press <title>...      presses each button, tab, radio button, or switch with that title, description, help
//                                    text, or identifier, in order. When several match, it presses the first.
//   axdo <pid> windows               the CoreGraphics window number, layer, bounds, and title of each window
//   axdo <pid> frame [x y w h]       prints the frame of the window that holds the Settings pages, or sets it first
//   axdo <pid> cutoff                each text in view that is cut off: a one-line text or button whose whole title is
//                                    wider than its frame, or a text or control that runs past its window's edge.
//                                    Exits 1 if any. A button whose VoiceOver label differs from its title can be
//                                    reported wrongly, so check each report in a screenshot. Run it with the app's
//                                    language, such as `-AppleLanguages (ja)`, so Chinese and Japanese text measures
//                                    with the same fallback fonts as in the app.
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

func frame(_ element: AXUIElement) -> CGRect? {
    guard let value = attribute(element, "AXFrame"), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var rect = CGRect.zero
    return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil
}

/// The font of a text's first character, as the app reports it to Accessibility.
func font(_ element: AXUIElement, _ text: String) -> NSFont? {
    var range = CFRange(location: 0, length: min(1, text.utf16.count))
    guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
    var value: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element, "AXAttributedStringForRange" as CFString, parameter, &value) == .success,
        let string = value as? NSAttributedString, string.length > 0,
        let info = string.attribute(NSAttributedString.Key("AXFont"), at: 0, effectiveRange: nil) as? [String: Any],
        let size = info["AXFontSize"] as? Double
    else { return nil }
    let name = info["AXFontName"] as? String ?? ""
    // The system font's private names, such as .SFNS-Semibold, do not load by name, so match the weight instead.
    let weights: [(String, NSFont.Weight)] = [("Bold", .bold), ("Semibold", .semibold), ("Medium", .medium)]
    let weight = weights.first { name.contains($0.0) }?.1 ?? .regular
    return name.contains("Mono") ? .monospacedSystemFont(ofSize: size, weight: weight) : .systemFont(ofSize: size, weight: weight)
}

/// Where the last character of a text is drawn. A text whose VoiceOver label replaces its drawn text, such as a key
/// cap, and a text that joins several texts, report their whole frame here instead of one character's box.
func lastCharacterBounds(_ element: AXUIElement, _ text: String) -> CGRect? {
    var range = CFRange(location: text.utf16.count - 1, length: 1)
    guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
    var value: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element, "AXBoundsForRange" as CFString, parameter, &value) == .success,
        let value, CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    var rect = CGRect.zero
    return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil
}

func usage() -> Never {
    FileHandle.standardError.write(Data(
        "usage: axdo <pid> dump|status|press <title>...|windows|cutoff, or axdo frontmost|builtin-display|hide <bundle id>|unhide <pid>...\n".utf8))
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
        // After Miri relaunched, the engine once still tiled the window of an app that was already hidden.
        // Showing such an app first makes the next hide send a fresh hide event.
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
                // A Settings page also has an identifier such as miri.page.general, which is the same in every language.
                for name in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, "AXIdentifier"] {
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
case "frame":
    // The Settings window is the one with the sidebar page miri.page.general. Its title changes with the language.
    func isSettings(_ window: AXUIElement) -> Bool {
        var found = false
        walk(window) { element, _ in found = found || text(element, "AXIdentifier") == "miri.page.general" }
        return found
    }
    guard let window = windows.first(where: isSettings) else {
        print("no Settings window")
        exit(1)
    }
    if arguments.count == 7, let numbers = Optional(arguments[3...6].compactMap(Double.init)), numbers.count == 4 {
        var size = CGSize(width: numbers[2], height: numbers[3])
        var origin = CGPoint(x: numbers[0], y: numbers[1])
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &origin)!)
    } else if arguments.count != 3 {
        usage()
    }
    let box = frame(window) ?? .zero
    print("\(Int(box.minX)) \(Int(box.minY)) \(Int(box.width)) \(Int(box.height))")
case "cutoff":
    var problems = 0
    for window in windows {
        guard let bounds = frame(window) else { continue }
        walk(window) { element, _ in
            let role = text(element, kAXRoleAttribute) ?? ""
            // Miri's segmented controls report frames up to 69 points away from where they draw, so skip them.
            guard role != kAXWindowRole as String, role != kAXRadioButtonRole as String,
                let box = frame(element), box.width > 0, box.height > 0,
                box.maxY > bounds.minY, box.minY < bounds.maxY  // in view, not scrolled away
            else { return }
            let label = [text(element, kAXValueAttribute), text(element, kAXTitleAttribute), text(element, kAXDescriptionAttribute)]
                .compactMap { $0 }.first { !$0.isEmpty } ?? ""
            guard !label.isEmpty else { return }
            var problem: String?
            if box.maxX > bounds.maxX + 1 || box.minX < bounds.minX - 1 {
                problem = "runs past the window edge by \(Int(max(box.maxX - bounds.maxX, bounds.minX - box.minX))) pt"
            } else if role == kAXButtonRole as String, attribute(element, kAXSubroleAttribute) == nil,
                box.width >= 40, box.height <= 30  // a text button on one line, not an icon or a window button
            {
                // Buttons report no font. A push button uses the 13-point system font, a small one (20 points high)
                // the 11-point font, with at least 6 points on each side.
                let size: CGFloat = box.height <= 21 ? 11 : 13
                let needed = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size)]).width + 12
                if needed > box.width + 1 { problem = "title needs \(Int(needed)) pt, has \(Int(box.width)) pt" }
            } else if role == kAXStaticTextRole as String, let drawn = text(element, kAXValueAttribute), drawn == label,
                (text(element, kAXDescriptionAttribute) ?? "").isEmpty,  // else the value is VoiceOver's, not drawn
                let last = lastCharacterBounds(element, drawn), last != box,  // the value is the drawn text
                let font = font(element, drawn),
                box.height < (font.ascender - font.descender + font.leading) * 1.5  // one line: a wrapped text is fine
            {
                // A text cut off on one line keeps its whole string for Accessibility, so measure that string.
                let needed = (drawn as NSString).size(withAttributes: [.font: font]).width
                if needed > box.width + 2 { problem = "needs \(Int(needed)) pt on one line, has \(Int(box.width)) pt" }
            }
            if let problem {
                problems += 1
                print("CUT \(role) \(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))x\(Int(box.height)): \(problem): \(label.prefix(80))")
            }
        }
    }
    print("\(problems) cut off")
    exit(problems == 0 ? 0 : 1)
default:
    usage()
}
