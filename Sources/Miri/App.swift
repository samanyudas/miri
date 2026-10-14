import AppKit
import SwiftUI

@main
struct MiriApp: App {
    @NSApplicationDelegateAdaptor(PrototypeDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Miri permission experiment") {
            ExperimentView(experiment: delegate.experiment)
                .frame(width: 560, height: 360)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Miri", action: delegate.experiment.quit).keyboardShortcut("q")
            }
        }
    }
}

final class PrototypeDelegate: NSObject, NSApplicationDelegate {
    let experiment = PermissionExperiment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard !arguments.isEmpty else { return }
        guard arguments.count == 4, arguments[0] == "--permission-observation",
            arguments[2] == "--target-pid", let pid = Int32(arguments[3]), pid > 0
        else {
            exit(2)
        }
        NSApplication.shared.setActivationPolicy(.accessory)
        let destination = URL(fileURLWithPath: arguments[1])
        do {
            try Data(String(getpid()).utf8).write(to: destination.appendingPathExtension("pid"), options: .atomic)
        } catch { exit(1) }
        experiment.check(targetPid: pid) { result in
            do {
                let data: Data
                switch result {
                case .success(let report): data = try JSONEncoder().encode(report)
                case .failure(let error):
                    data = try JSONSerialization.data(withJSONObject: [
                        "schemaVersion": 1, "failure": error.localizedDescription,
                        "appPid": getpid(), "permissionAttribution": "unresolved",
                    ])
                }
                try data.write(to: destination, options: .atomic)
            } catch {
                exit(1)
            }
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if case .checking = experiment.state {
            experiment.quit()
            return .terminateCancel
        }
        return .terminateNow
    }
}

struct ExperimentView: View {
    let experiment: PermissionExperiment
    @State private var targetPid = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accessibility permission experiment").font(.title2).fontWeight(.semibold)
            Text(
                "Compare Miri and its bundled engine against a harmless fixture. Permission attribution remains unresolved until a manual grant comparison."
            )
            .foregroundStyle(.secondary)
            HStack {
                TextField("Fixture process ID", text: $targetPid).frame(width: 180)
                Button("Check permission") {
                    if let pid = Int32(targetPid), pid > 0 { experiment.check(targetPid: pid) }
                }
                .disabled((Int32(targetPid).map { $0 <= 0 } ?? true) || isChecking)
            }
            Group {
                switch experiment.state {
                case .idle: Text("Start AXFixture, then enter its process ID.")
                case .checking: ProgressView("Checking app and engine...")
                case .failed(let message): Text(message).foregroundStyle(.red)
                case .observed(let report):
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "Miri trusted: \(report.app.trusted.description). AX read: \(report.app.readCode). Role: \(report.app.role ?? "none")."
                        )
                        Text(
                            "Engine trusted: \(report.engine.trusted.description). AX read: \(report.engine.readCode). Role: \(report.engine.role ?? "none")."
                        )
                        Text("Engine process \(report.engine.pid). Attribution unresolved.").foregroundStyle(.secondary)
                    }.textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Open Accessibility Settings") {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
                Button("Quit", action: experiment.quit)
            }
        }.padding(24)
    }

    private var isChecking: Bool {
        if case .checking = experiment.state { true } else { false }
    }
}
