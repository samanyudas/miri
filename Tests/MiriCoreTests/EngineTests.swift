import Foundation
import Testing

@testable import MiriCore

@MainActor final class FakeEngine: EngineProcess {
    let pid: Int32
    let onExit: @MainActor (Int32) -> Void
    var interrupts = 0
    var kills = 0
    /// When true, the fake exits as soon as it is interrupted, like an engine whose cleanup finishes.
    var exitsOnInterrupt = true

    init(pid: Int32, onExit: @escaping @MainActor (Int32) -> Void) {
        self.pid = pid
        self.onExit = onExit
    }

    func interrupt() {
        interrupts += 1
        if exitsOnInterrupt { onExit(0) }
    }

    func kill() {
        kills += 1
        onExit(9)
    }

    func crash() { onExit(6) }
}

@MainActor final class FakeLauncher: EngineLauncher {
    var engines: [FakeEngine] = []
    var failure: Error?

    func launch(onExit: @escaping @MainActor (Int32) -> Void) throws -> any EngineProcess {
        if let failure { throw failure }
        let engine = FakeEngine(pid: Int32(100 + engines.count), onExit: onExit)
        engines.append(engine)
        return engine
    }
}

@MainActor struct EngineSupervisorTests {
    let launcher = FakeLauncher()

    private func supervisor(recovered: @escaping () -> Void = {}, now: @escaping () -> Date = { .now })
        -> EngineSupervisor
    {
        EngineSupervisor(launcher: launcher, recoverWindows: recovered, now: now)
    }

    /// Waits up to five seconds for `condition`, so a timer that a loaded machine runs late does not fail the test.
    private func eventually(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func startsAndStopsCleanlyAndRecoversWindows() async {
        var recovered = 0
        let engine = supervisor(recovered: { recovered += 1 })
        engine.start()
        #expect(engine.state == .running(pid: 100))
        engine.start()
        #expect(launcher.engines.count == 1)
        var stopped = false
        engine.stop { stopped = true }
        #expect(stopped)
        #expect(engine.state == .stopped)
        #expect(launcher.engines[0].interrupts == 1)
        #expect(recovered == 1)
    }

    @Test func killsAnEngineThatIgnoresTheStopRequest() async throws {
        let engine = supervisor()
        engine.start()
        launcher.engines[0].exitsOnInterrupt = false
        var stopped = false
        engine.stop { stopped = true }
        #expect(!stopped)
        try await eventually { stopped }
        #expect(launcher.engines[0].kills == 1)
        #expect(stopped)
        #expect(engine.state == .stopped)
    }

    @Test func restartsAfterACrashAndRecoversWindowsFirst() async throws {
        var recovered = 0
        let engine = supervisor(recovered: { recovered += 1 })
        engine.start()
        launcher.engines[0].crash()
        #expect(engine.state == .restarting(crashes: 1))
        #expect(recovered == 1)
        try await eventually { engine.state == .running(pid: 101) }
        #expect(engine.state == .running(pid: 101))
    }

    @Test func stopsRetryingAfterThreeCrashesWithinFiveMinutes() async throws {
        var now = Date(timeIntervalSince1970: 0)
        let engine = supervisor(now: { now })
        engine.start()
        for crash in 1...3 {
            launcher.engines.last?.crash()
            if crash < 3 {
                #expect(engine.state == .restarting(crashes: crash))
                engine.start()
                now += 60
            }
        }
        guard case .failed = engine.state else {
            Issue.record("Expected failure, got \(engine.state)")
            return
        }
        engine.restartManually()
        #expect(engine.state == .running(pid: 103))
        launcher.engines.last?.crash()
        #expect(engine.state == .restarting(crashes: 1))
        engine.stop()
    }

    @Test func stopCancelsAPendingRestart() async throws {
        let engine = supervisor()
        engine.start()
        launcher.engines[0].crash()
        engine.stop()
        #expect(engine.state == .stopped)
        try await Task.sleep(for: EngineSupervisor.restartDelay + .milliseconds(300))
        #expect(engine.state == .stopped)
        #expect(launcher.engines.count == 1)
    }

    @Test func reportsALaunchFailure() {
        launcher.failure = CocoaError(.fileNoSuchFile)
        let engine = supervisor()
        engine.start()
        guard case .failed(let message) = engine.state else {
            Issue.record("Expected failure, got \(engine.state)")
            return
        }
        #expect(message.hasPrefix("The engine could not start."))
    }
}

struct CrashPolicyTests {
    @Test func countsOnlyCrashesWithinTheWindow() {
        var policy = CrashPolicy()
        let start = Date(timeIntervalSince1970: 0)
        let decisions = [0, 100, 301, 350].map { policy.recordCrash(at: start + $0) }
        #expect(decisions == [true, true, true, false])
        policy.reset()
        let afterReset = policy.recordCrash(at: start + 351)
        #expect(afterReset)
    }
}

struct EngineEnvironmentTests {
    @Test func isolatesTheEngineFromStandalonePaneru() {
        let support = URL(filePath: "/Users/test/Library/Application Support/Miri")
        let paths = EnginePaths(
            executable: URL(filePath: "/Applications/Miri.app/Contents/Helpers/miri-engine"), support: support,
            serviceName: "io.github.samanyudas.miri.engine")
        let environment = paths.environment(from: [
            "HOME": "/Users/test", "PANERU_CONFIG": "/Users/test/.paneru.toml", "PANERU_LUA_PATH": "x",
            "XDG_CONFIG_HOME": "/Users/test/.config", "PATH": "/usr/bin",
        ])
        #expect(environment["PANERU_CONFIG"] == support.path + "/config.toml")
        #expect(environment["PANERU_MACH_SERVICE"] == "io.github.samanyudas.miri.engine")
        #expect(environment["PANERU_LUA_PATH"] == nil)
        #expect(environment["PATH"] == "/usr/bin")
        for key in ["XDG_CONFIG_HOME", "XDG_CONFIG_DIRS", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"] {
            #expect(environment[key]?.hasPrefix(support.path + "/Engine/") == true, "\(key)")
        }
    }
}

struct RotatingLogTests {
    @Test func keepsAtMostTwoFilesOfTheLimit() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "miri-log-\(UUID().uuidString)")
        let log = RotatingLog(url: directory.appending(path: "engine.log"), limit: 100)
        for line in 0..<50 { log.append(Data("line \(line)\n".utf8)) }
        let current = try Data(contentsOf: log.url)
        let previous = try Data(contentsOf: log.previousURL)
        #expect(current.count <= 100)
        #expect(previous.count <= 100)
        #expect(log.tail(maximum: 1000).hasSuffix("line 49\n"))
        #expect(log.tail(maximum: 8) == "line 49\n")
        log.append(Data(repeating: 65, count: 500))
        #expect(try Data(contentsOf: log.url).count == 100)
    }
}

/// Runs the real launcher against a shell script that stands in for the engine.
@MainActor struct ProcessEngineLauncherTests {
    private let support = FileManager.default.temporaryDirectory.appending(path: "miri-engine-\(UUID().uuidString)")

    private func launcher(script: String) throws -> ProcessEngineLauncher {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let executable = support.appending(path: "fake-engine")
        try ("#!/bin/sh\n" + script).write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let paths = EnginePaths(executable: executable, support: support, serviceName: "test.miri.engine")
        try Data().write(to: paths.configuration)
        return ProcessEngineLauncher(paths: paths, log: RotatingLog(url: paths.logs.appending(path: "engine.log")))
    }

    private func waitForExit(_ exited: () -> Int32?) async throws -> Int32 {
        for _ in 0..<200 {
            if let status = exited() { return status }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw CancellationError()
    }

    private func waitForReady(_ launcher: ProcessEngineLauncher) async throws {
        _ = try await waitForExit { launcher.log.tail(maximum: 1000).contains("ready") ? 0 : nil }
    }

    @Test func passesTheEnvironmentAndCapturesOutput() async throws {
        let launcher = try launcher(script: "echo \"$1 $PANERU_CONFIG $PANERU_MACH_SERVICE\"; echo oops >&2; exit 3\n")
        var status: Int32?
        _ = try launcher.launch { status = $0 }
        #expect(try await waitForExit { status } == 3)
        let log = launcher.log.tail(maximum: 10_000)
        #expect(log.contains("launch \(launcher.paths.configuration.path) test.miri.engine\n"))
        #expect(log.contains("oops\n"))
    }

    @Test func interruptLetsTheEngineCleanUp() async throws {
        let launcher = try launcher(
            script: "trap 'echo cleaned; exit 0' INT\necho ready\nwhile :; do sleep 0.05; done\n")
        var status: Int32?
        let engine = try launcher.launch { status = $0 }
        try await waitForReady(launcher)
        engine.interrupt()
        #expect(try await waitForExit { status } == 0)
        #expect(launcher.log.tail(maximum: 1000).contains("cleaned"))
    }

    @Test func killEndsAnEngineThatIgnoresInterrupt() async throws {
        let launcher = try launcher(script: "trap '' INT\necho ready\nwhile :; do sleep 0.05; done\n")
        var status: Int32?
        let engine = try launcher.launch { status = $0 }
        try await waitForReady(launcher)
        engine.interrupt()
        try await Task.sleep(for: .milliseconds(200))
        #expect(status == nil)
        engine.kill()
        #expect(try await waitForExit { status } == SIGKILL)
    }

    @Test func refusesToStartWithoutTheConfigurationFile() throws {
        let launcher = try launcher(script: "exit 0\n")
        try FileManager.default.removeItem(at: launcher.paths.configuration)
        #expect(throws: CocoaError.self) { try launcher.launch { _ in } }
    }
}
