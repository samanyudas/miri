import AppKit
import ApplicationServices
import Observation

struct AXObservation: Codable {
    let schemaVersion: Int
    let pid: Int32
    let targetPid: Int32
    let trusted: Bool
    let messagingTimeoutCode: Int32
    let readCode: Int32
    let role: String?
    let executable: String
    let bundleIdentifier: String?
}

struct Report: Encodable {
    let schemaVersion = 1
    let app: AXObservation
    let engine: AXObservation
    let engineRevision: String
    let bundlePath: String
    let permissionAttribution = "unresolved"
}

enum ObservationState {
    case idle
    case checking
    case observed(Report)
    case failed(String)
}

enum ExperimentError: LocalizedError {
    case failure(String)

    var errorDescription: String? {
        switch self {
        case .failure(let message): message
        }
    }
}

@Observable
final class PermissionExperiment {
    private(set) var state: ObservationState = .idle
    private var task: Task<Void, Never>?

    func check(targetPid: Int32, completion: ((Result<Report, Error>) -> Void)? = nil) {
        guard task == nil else { return }
        state = .checking
        task = Task {
            let result: Result<Report, Error>
            do {
                result = .success(try await observe(targetPid: targetPid))
            } catch {
                result = .failure(error)
            }
            switch result {
            case .success(let report): state = .observed(report)
            case .failure(let error): state = .failed(error.localizedDescription)
            }
            task = nil
            completion?(result)
        }
    }

    func quit() {
        task?.cancel()
        Task {
            await task?.value
            NSApplication.shared.terminate(nil)
        }
    }

    private func observe(targetPid: Int32) async throws -> Report {
        guard targetPid > 0, kill(targetPid, 0) == 0 else {
            throw ExperimentError.failure("The fixture process is unavailable.")
        }
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/miri-engine")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ExperimentError.failure("The bundled engine is missing or is not executable.")
        }
        let element = AXUIElementCreateApplication(targetPid)
        let timeout = AXUIElementSetMessagingTimeout(element, 1)
        var role: CFTypeRef?
        let read = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let app = AXObservation(
            schemaVersion: 1, pid: getpid(), targetPid: targetPid,
            trusted: AXIsProcessTrusted(), messagingTimeoutCode: timeout.rawValue,
            readCode: read.rawValue, role: role as? String,
            executable: Bundle.main.executableURL?.path ?? "",
            bundleIdentifier: Bundle.main.bundleIdentifier
        )
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("stdout")
        let errors = directory.appendingPathComponent("stderr")
        for url in [output, errors] {
            guard FileManager.default.createFile(atPath: url.path, contents: nil,
                                                 attributes: [.posixPermissions: 0o600]) else {
                throw ExperimentError.failure("Cannot create the engine output file.")
            }
        }
        let stdout = try FileHandle(forWritingTo: output)
        let stderr = try FileHandle(forWritingTo: errors)
        defer { try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["miri-ax-probe", "--target-pid", String(targetPid)]
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "PANERU_CONFIG")
        process.environment = environment
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        defer {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while process.isRunning {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else {
                throw ExperimentError.failure("The engine did not finish within five seconds.")
            }
            for url in [output, errors] {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 16_384 else {
                    throw ExperimentError.failure("The engine response exceeds the size limit.")
                }
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        process.waitUntilExit()
        for url in [output, errors] {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 16_384 else {
                throw ExperimentError.failure("The engine response exceeds the size limit.")
            }
        }
        guard process.terminationStatus == 0 else {
            throw ExperimentError.failure("The engine exited with code \(process.terminationStatus).")
        }
        let response = try FileHandle(forReadingFrom: output)
        defer { try? response.close() }
        let data = try response.read(upToCount: 16_385) ?? Data()
        guard data.count <= 16_384 else {
            throw ExperimentError.failure("The engine response exceeds the size limit.")
        }
        let engine = try JSONDecoder().decode(AXObservation.self, from: data)
        guard engine.schemaVersion == 1, engine.pid == process.processIdentifier,
              engine.targetPid == targetPid, engine.executable == executable.path,
              engine.bundleIdentifier == "io.github.samanyudas.miri.engine" else {
            throw ExperimentError.failure("The engine response has an unexpected identity or schema.")
        }
        let revisionURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/engine-revision.txt")
        let revision = try String(contentsOf: revisionURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Report(app: app, engine: engine, engineRevision: revision, bundlePath: Bundle.main.bundlePath)
    }
}
