import AppKit

// Options:
//   --ready-file <path>  writes the process ID to <path> once the window shows
//   --label <text>       adds <text> to the window title and text, so evidence names each fixture
//   --resizable          lets the window resize, so the engine tiles it in a column instead of floating it
//   --activate           brings the fixture to the front, as when a person opens an app
struct Options {
    var readyFile: String?
    var label: String?
    var resizable = false
    var activate = false

    init(_ arguments: [String]) {
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            switch argument {
            case "--ready-file": readyFile = rest.popFirst()
            case "--label": label = rest.popFirst()
            case "--resizable": resizable = true
            case "--activate": activate = true
            default:
                FileHandle.standardError.write(Data("AXFixture: unknown option \(argument)\n".utf8))
                exit(2)
            }
        }
    }
}

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private let options = Options(Array(CommandLine.arguments.dropFirst()))
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let style: NSWindow.StyleMask = options.resizable ? [.titled, .closable, .resizable] : [.titled, .closable]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 140), styleMask: style, backing: .buffered, defer: false
        )
        let suffix = options.label.map { " - \($0)" } ?? ""
        window.title = "Miri harmless Accessibility fixture" + suffix
        // A wrapping label stays readable when the engine tiles the window into a narrow column.
        window.contentView = NSTextField(
            wrappingLabelWithString:
                "Test fixture\(suffix). Selftests may read or move this window. Process ID \(getpid()).")
        window.center()
        window.makeKeyAndOrderFront(nil)
        if options.activate { NSApplication.shared.activate() }
        self.window = window
        if let path = options.readyFile {
            do {
                try Data(String(getpid()).utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch { exit(1) }
        }
    }
}

let application = NSApplication.shared
let delegate = FixtureDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
