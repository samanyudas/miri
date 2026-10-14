import Foundation

/// Counts engine crashes and decides whether Miri restarts the engine or stops retrying.
public struct CrashPolicy: Sendable {
    public static let limit = 3
    public static let window: TimeInterval = 5 * 60

    private(set) var crashes: [Date] = []

    public init() {}

    /// Records a crash and returns `true` when Miri should restart the engine.
    public mutating func recordCrash(at time: Date) -> Bool {
        crashes = crashes.filter { time.timeIntervalSince($0) < Self.window } + [time]
        return crashes.count < Self.limit
    }

    public mutating func reset() { crashes.removeAll() }
}

/// What the app shows about the engine.
public enum EngineState: Equatable, Sendable {
    case stopped
    case running(pid: Int32)
    /// The engine crashed and Miri is starting it again.
    case restarting(crashes: Int)
    /// The engine crashed repeatedly, or could not start. Miri waits for a manual restart.
    case failed(String)

    public var isRunning: Bool {
        if case .running = self { true } else { false }
    }
}

/// A running engine process.
@MainActor public protocol EngineProcess: AnyObject {
    var pid: Int32 { get }
    /// Asks the engine to exit so its cleanup runs.
    func interrupt()
    /// Ends the engine immediately.
    func kill()
}

@MainActor public protocol EngineLauncher {
    /// Starts the engine. `onExit` runs on the main actor with the termination status when the process ends.
    func launch(onExit: @escaping @MainActor (Int32) -> Void) throws -> any EngineProcess
}

/// Starts, stops, and restarts the engine, and recovers windows whenever it stops.
@MainActor public final class EngineSupervisor {
    public static let stopTimeout: Duration = .seconds(3)
    public static let restartDelay: Duration = .seconds(1)

    public private(set) var state: EngineState = .stopped {
        didSet { if state != oldValue { onChange(state) } }
    }
    public var onChange: (EngineState) -> Void = { _ in }

    private let launcher: any EngineLauncher
    private let recoverWindows: () -> Void
    private var process: (any EngineProcess)?
    private var policy = CrashPolicy()
    private var stopRequested = false
    private var stopCompletions: [() -> Void] = []
    private var pendingRestart: Task<Void, Never>?
    private let now: () -> Date

    public init(
        launcher: any EngineLauncher, recoverWindows: @escaping () -> Void, now: @escaping () -> Date = Date.init
    ) {
        self.launcher = launcher
        self.recoverWindows = recoverWindows
        self.now = now
    }

    public func start() {
        guard process == nil else { return }
        pendingRestart?.cancel()
        pendingRestart = nil
        stopRequested = false
        do {
            let launched = try launcher.launch { [weak self] status in self?.exited(status: status) }
            process = launched
            state = .running(pid: launched.pid)
        } catch {
            state = .failed("The engine could not start. \(error.localizedDescription)")
        }
    }

    /// Starts the engine after the user asks, resetting the crash count.
    public func restartManually() {
        policy.reset()
        if process != nil {
            stop { [weak self] in self?.start() }
        } else {
            start()
        }
    }

    /// Asks the engine to exit, kills it after a timeout, then recovers windows. `completion` runs once it has exited.
    public func stop(completion: @escaping () -> Void = {}) {
        pendingRestart?.cancel()
        pendingRestart = nil
        guard let running = process else {
            state = .stopped
            completion()
            return
        }
        stopRequested = true
        stopCompletions.append(completion)
        running.interrupt()
        Task { [weak self, weak running] in
            try? await Task.sleep(for: Self.stopTimeout)
            guard let self, let running, self.process === running else { return }
            running.kill()
        }
    }

    private func exited(status: Int32) {
        process = nil
        recoverWindows()
        if stopRequested {
            stopRequested = false
            state = .stopped
            let completions = stopCompletions
            stopCompletions.removeAll()
            for completion in completions { completion() }
            return
        }
        guard policy.recordCrash(at: now()) else {
            state = .failed(
                "The engine stopped unexpectedly \(CrashPolicy.limit) times within five minutes. Miri stopped restarting it."
            )
            return
        }
        state = .restarting(crashes: policy.crashes.count)
        pendingRestart = Task { [weak self] in
            try? await Task.sleep(for: Self.restartDelay)
            guard !Task.isCancelled else { return }
            self?.start()
        }
    }
}
