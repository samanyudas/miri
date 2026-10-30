import CoreGraphics
import Foundation
import MiriCore

struct SystemScreenRecording: ScreenRecordingAccess {
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

    var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    func request() -> Bool { CGRequestScreenCaptureAccess() }
}
