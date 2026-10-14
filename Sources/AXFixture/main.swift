import AppKit

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 140),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Miri harmless Accessibility fixture"
        window.contentView = NSTextField(
            labelWithString: "Test fixture. Selftests may read or move this window. Process ID \(getpid()).")
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        let arguments = CommandLine.arguments
        if arguments.count == 3, arguments[1] == "--ready-file" {
            do {
                try Data(String(getpid()).utf8).write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
            } catch { exit(1) }
        }
    }
}

let application = NSApplication.shared
let delegate = FixtureDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
