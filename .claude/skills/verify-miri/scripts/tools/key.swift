// Posts one key press, down then up, at the HID event tap, where Miri and its engine read shortcuts.
// Usage: key <virtual key code> <event flags as hexadecimal>
// The flags must include the side-specific modifier bits (left Control 0x1, left Option 0x20, left Shift 0x2,
// left Command 0x8), or the engine does not match the chord. `verify-miri key` computes them from a chord.
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3, let code = UInt16(arguments[1]), let flags = UInt64(arguments[2], radix: 16) else {
    FileHandle.standardError.write(Data("usage: key <virtual key code> <flags hex>\n".utf8))
    exit(2)
}
let source = CGEventSource(stateID: .hidSystemState)
for down in [true, false] {
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { exit(1) }
    event.flags = CGEventFlags(rawValue: flags)
    event.post(tap: .cghidEventTap)
    usleep(30_000)
}
// Release the modifiers, as a keyboard does when the keys come up. Without this, the HID state keeps reporting
// them as held, and the next synthetic click inherits them: a leftover Command and Option made a click Hide Others.
guard let release = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false) else { exit(1) }
release.type = .flagsChanged
release.flags = []
release.post(tap: .cghidEventTap)
print("posted key \(code) flags 0x\(String(flags, radix: 16)) at \(Date().timeIntervalSince1970)")
