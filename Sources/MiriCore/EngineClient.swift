import Foundation

extension EnginePaths {
    /// Runs one request against the bundled daemon. Keep pipe I/O off the UI thread.
    @concurrent public func request(_ arguments: [String]) async -> Data? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment(from: ProcessInfo.processInfo.environment)
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let timeout = DispatchWorkItem { process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: timeout)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        return process.terminationStatus == 0 ? data : nil
    }
}
