import Foundation

/// Where Miri keeps the engine's files. Every path is inside Miri's own Application Support folder.
public struct EnginePaths: Sendable {
    public let executable: URL
    public let configuration: URL
    public let support: URL
    public let logs: URL
    /// The Mach service name. It differs from standalone Paneru's, so the two never talk to each other.
    public let serviceName: String

    public init(executable: URL, support: URL, serviceName: String) {
        self.executable = executable
        self.support = support
        self.serviceName = serviceName
        configuration = support.appending(path: "config.toml")
        logs = support.appending(path: "Logs")
    }

    /// The engine's environment. XDG folders point inside Miri's folder, so the engine cannot find standalone
    /// Paneru's configuration, session state, or script state.
    public func environment(from inherited: [String: String]) -> [String: String] {
        var environment = inherited.filter { !$0.key.hasPrefix("PANERU_") && !$0.key.hasPrefix("XDG_") }
        environment["PANERU_CONFIG"] = configuration.path
        environment["PANERU_MACH_SERVICE"] = serviceName
        environment["XDG_CONFIG_HOME"] = support.appending(path: "Engine/config").path
        environment["XDG_CONFIG_DIRS"] = support.appending(path: "Engine/config").path
        environment["XDG_STATE_HOME"] = support.appending(path: "Engine/state").path
        environment["XDG_DATA_HOME"] = support.appending(path: "Engine/data").path
        environment["XDG_CACHE_HOME"] = support.appending(path: "Engine/cache").path
        environment["NO_COLOR"] = "1"
        return environment
    }
}

/// An append-only log that keeps at most two files of `limit` bytes each, so engine logs stay bounded.
public final class RotatingLog: @unchecked Sendable {
    public static let defaultLimit = 1 << 20

    public let url: URL
    public var previousURL: URL { url.deletingPathExtension().appendingPathExtension("1.log") }
    private let limit: Int
    private let lock = NSLock()

    public init(url: URL, limit: Int = RotatingLog.defaultLimit) {
        self.url = url
        self.limit = limit
    }

    public func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.withLock {
            let manager = FileManager.default
            try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let size = (try? manager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if size + data.count > limit, size > 0 {
                try? manager.removeItem(at: previousURL)
                try? manager.moveItem(at: url, to: previousURL)
            }
            if !manager.fileExists(atPath: url.path) {
                manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data.count > limit ? data.suffix(limit) : data)
        }
    }

    /// The newest `maximum` bytes across both files, oldest first.
    public func tail(maximum: Int) -> String {
        lock.withLock {
            let data = [previousURL, url].compactMap { try? Data(contentsOf: $0) }.reduce(Data(), +)
            return String(decoding: data.suffix(maximum), as: UTF8.self)
        }
    }
}

/// Runs the bundled engine binary with Miri's isolated environment and captures its output in a bounded log.
public struct ProcessEngineLauncher: EngineLauncher {
    public let paths: EnginePaths
    public let log: RotatingLog

    public init(paths: EnginePaths, log: RotatingLog) {
        self.paths = paths
        self.log = log
    }

    public func launch(onExit: @escaping @MainActor (Int32) -> Void) throws -> any EngineProcess {
        guard FileManager.default.fileExists(atPath: paths.configuration.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: paths.configuration.path])
        }
        let process = Process()
        process.executableURL = paths.executable
        process.arguments = ["launch"]
        process.environment = paths.environment(from: ProcessInfo.processInfo.environment)
        process.currentDirectoryURL = paths.support
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        process.standardInput = FileHandle.nullDevice
        let log = log
        output.fileHandleForReading.readabilityHandler = { handle in log.append(handle.availableData) }
        process.terminationHandler = { finished in
            output.fileHandleForReading.readabilityHandler = nil
            log.append(output.fileHandleForReading.readDataToEndOfFile())
            let status = finished.terminationStatus
            Task { @MainActor in onExit(status) }
        }
        log.append(Data("--- Miri started the engine at \(Date.now.ISO8601Format()) ---\n".utf8))
        try process.run()
        return RunningEngine(process: process)
    }
}

@MainActor final class RunningEngine: EngineProcess {
    private let process: Process

    init(process: Process) { self.process = process }

    var pid: Int32 { process.processIdentifier }

    func interrupt() { process.interrupt() }

    func kill() {
        guard process.isRunning else { return }
        Darwin.kill(process.processIdentifier, SIGKILL)
    }
}
