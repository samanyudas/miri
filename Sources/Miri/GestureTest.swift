import AppKit
import MiriCore
import Observation

/// One run of the gesture test. It turns on the selected swipe, watches the engine's strip move while the user
/// swipes, fails on a macOS Space switch, and saves a result only after the user confirms it.
@Observable final class GestureTest {
    enum Phase: Equatable {
        case idle
        case watching(movementSeen: Bool)
        case passedAwaitingConfirmation
        case failed(String)
        case inconclusive
    }

    static let pollInterval: Duration = .milliseconds(150)
    static let timeout: Duration = .seconds(20)
    /// How long the test keeps watching after the strip moved both ways, so a late Space switch still fails it.
    static let settle: Duration = .seconds(1)

    private(set) var phase = Phase.idle
    private(set) var fingers: GestureFingers?

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private var candidate: GestureVerification?
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        stop()
        do {
            let candidate = try model.beginGestureTest()
            self.candidate = candidate
            fingers = candidate.fingers
        } catch {
            phase = .failed(error.message)
            return
        }
        phase = .watching(movementSeen: false)
        watchForMacOSActions()
        let paths = model.paths
        watcher = Task { [weak self] in await self?.watch(paths) }
    }

    /// The user saw the strip follow their fingers.
    func confirm() {
        guard phase == .passedAwaitingConfirmation, var verification = candidate else { return }
        verification.date = .now
        stop()
        phase = .idle
        model.finishGestureTest(.confirmed(verification))
    }

    /// The user saw the strip not follow their fingers.
    func deny() {
        guard phase == .passedAwaitingConfirmation else { return }
        fail(.failed("You reported that the strip did not follow your fingers."))
    }

    /// Ends a running test without a result, as when the sheet closes.
    func cancel() {
        guard candidate != nil else { return }
        stop()
        phase = .idle
        model.finishGestureTest(.cancelled)
    }

    private func fail(_ phase: Phase) {
        stop()
        self.phase = phase
        model.finishGestureTest(.failed)
    }

    private func stop() {
        watcher?.cancel()
        watcher = nil
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers = []
        candidate = nil
    }

    private func watch(_ paths: EnginePaths) async {
        let clock = ContinuousClock()
        let deadline = clock.now + Self.timeout
        var previous = await Self.readState(paths)
        var directions: Set<StripMovement> = []
        var passAt: ContinuousClock.Instant?
        while !Task.isCancelled, case .watching = phase {
            try? await Task.sleep(for: Self.pollInterval)
            guard !Task.isCancelled, case .watching = phase else { return }
            let current = await Self.readState(paths)
            if let previous, let current, let movement = StripMovement.between(previous, current) {
                directions.insert(movement)
                phase = .watching(movementSeen: true)
                if directions.count == 2, passAt == nil { passAt = clock.now + Self.settle }
            }
            previous = current ?? previous
            if let passAt, clock.now >= passAt {
                phase = .passedAwaitingConfirmation
                return
            }
            if clock.now >= deadline {
                fail(.inconclusive)
                return
            }
        }
    }

    /// The horizontal macOS swipes that clash with the strip swipe all switch Spaces. An app switch is not one:
    /// the strip focuses the window it lands on, which activates that window's app.
    private func watchForMacOSActions() {
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.macOSActed("macOS switched Spaces.") }
            }
        ]
    }

    private func macOSActed(_ reason: String) {
        switch phase {
        case .watching, .passedAwaitingConfirmation: fail(.failed(reason))
        case .idle, .failed, .inconclusive: break
        }
    }

    /// Runs `miri-engine query state --json` against Miri's engine. A query that takes longer than a second is
    /// ended, so a stuck engine cannot stall the test past its timeout.
    @concurrent private static func readState(_ paths: EnginePaths) async -> EngineStateSnapshot? {
        let process = Process()
        process.executableURL = paths.executable
        process.arguments = ["query", "state", "--json"]
        process.environment = paths.environment(from: ProcessInfo.processInfo.environment)
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { if process.isRunning { process.terminate() } }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return try? EngineStateSnapshot(json: data)
    }
}
