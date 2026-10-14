import AppKit
import SwiftUI

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
                case .checking: ProgressView("Checking app and engine…")
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
