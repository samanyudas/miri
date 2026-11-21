// Captures one display with only the listed windows in the picture, so PR evidence never shows other apps.
//
//   fixturecap still <out.png> <display id> <window id>...
//   fixturecap record <out.mov> <max seconds> <display id> <window id>...
//
// ScreenCaptureKit draws only the included windows over a plain background: no wallpaper, no menu bar, no
// cursor, and no other app, even where another window covers a listed one. A recording stops at SIGINT or
// SIGTERM, or after <max seconds>.
import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit
import UniformTypeIdentifiers

/// The plain grey behind the windows. `SCStreamConfiguration` does not retain its color, so it lives here.
let background = CGColor(gray: 0.93, alpha: 1)

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("fixturecap: \(message)\n".utf8))
  exit(1)
}

func filter(display displayID: UInt32, windows windowIDs: [UInt32]) async throws -> (SCContentFilter, SCStreamConfiguration) {
  let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
  guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
    fail("no display \(displayID); displays are \(content.displays.map(\.displayID))")
  }
  let windows = content.windows.filter { windowIDs.contains($0.windowID) }
  let missing = Set(windowIDs).subtracting(windows.map(\.windowID))
  if !missing.isEmpty { fail("no window \(missing.sorted())") }
  let filter = SCContentFilter(display: display, including: windows)
  let config = SCStreamConfiguration()
  let scale = Int(filter.pointPixelScale)
  config.width = display.width * scale
  config.height = display.height * scale
  config.showsCursor = false
  config.backgroundColor = background
  config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
  return (filter, config)
}

func number(_ text: String) -> UInt32 {
  guard let value = UInt32(text) else { fail("not a number: \(text)") }
  return value
}

/// Reports when the recording file is complete.
final class Recorder: NSObject, SCRecordingOutputDelegate {
  let finished: AsyncStream<Void>
  private let done: AsyncStream<Void>.Continuation

  override init() {
    (finished, done) = AsyncStream.makeStream(of: Void.self)
  }

  func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { done.yield() }

  func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
    FileHandle.standardError.write(Data("fixturecap: recording failed: \(error)\n".utf8))
    done.yield()
  }
}

// The macOS 27 SDK picks the completion-handler forms of these two calls even under `await`, so wrap them.
extension SCStream {
  func start() async throws {
    try await withCheckedThrowingContinuation { (resume: CheckedContinuation<Void, any Error>) in
      startCapture { error in error.map { resume.resume(throwing: $0) } ?? resume.resume() }
    }
  }

  func stop() async throws {
    try await withCheckedThrowingContinuation { (resume: CheckedContinuation<Void, any Error>) in
      stopCapture { error in error.map { resume.resume(throwing: $0) } ?? resume.resume() }
    }
  }
}

/// Returns at SIGINT, SIGTERM, or after `seconds`, whichever comes first.
func waitForStop(seconds: Double) async {
  let (events, event) = AsyncStream.makeStream(of: Void.self)
  let sources = [SIGINT, SIGTERM].map { number in
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
    source.setEventHandler { event.yield() }
    source.resume()
    return source
  }
  let timer = Task {
    try? await Task.sleep(for: .seconds(seconds))
    event.yield()
  }
  for await _ in events { break }
  timer.cancel()
  sources.forEach { $0.cancel() }
}

let arguments = CommandLine.arguments
guard arguments.count >= 5 else {
  fail("usage: fixturecap still <out.png> <display> <window>... | record <out.mov> <seconds> <display> <window>...")
}
let out = URL(fileURLWithPath: arguments[2])

switch arguments[1] {
case "still":
  let (contentFilter, config) = try await filter(display: number(arguments[3]), windows: arguments[4...].map(number))
  let image: CGImage = try await SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: config)
  guard let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fail("cannot write \(out.path)")
  }
  CGImageDestinationAddImage(destination, image, nil)
  if !CGImageDestinationFinalize(destination) { fail("cannot write \(out.path)") }
  print(out.path)
case "record":
  guard arguments.count >= 6, let seconds = Double(arguments[3]) else { fail("record needs <out.mov> <seconds> <display> <window>...") }
  let (contentFilter, config) = try await filter(display: number(arguments[4]), windows: arguments[5...].map(number))
  let stream = SCStream(filter: contentFilter, configuration: config, delegate: nil)
  let recordingConfig = SCRecordingOutputConfiguration()
  recordingConfig.outputURL = out
  recordingConfig.outputFileType = .mov
  let recorder = Recorder()
  try stream.addRecordingOutput(SCRecordingOutput(configuration: recordingConfig, delegate: recorder))
  try await stream.start()
  print("recording \(out.path)")
  fflush(stdout)
  await waitForStop(seconds: seconds)
  try await stream.stop()
  for await _ in recorder.finished { break }
  print(out.path)
default:
  fail("unknown mode \(arguments[1])")
}
