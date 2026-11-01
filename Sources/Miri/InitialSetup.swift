import SwiftUI

/// The window Miri opens on first launch. It shows what blocks window management and recommends the strip swipe.
/// The v2 shortcut tour (#81) is deliberately not here.
struct InitialSetupView: View {
    let model: AppModel
    @Environment(\.presenter) private var presenter

    var body: some View {
        VStack(spacing: 0) {
            Form {
                ConfigurationIssueBanner(model: model)
                Section {
                    Text("Welcome to Miri").font(.title2.bold())
                    Text(
                        "Miri arranges the windows on each display side by side in a scrolling strip. Keyboard shortcuts work as soon as Miri is managing windows."
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                Section("Window Management") {
                    LabeledContent("Status", value: model.statusText)
                    ForEach(model.startBlockers) { check in
                        SetupCheckRow(check: check)
                    }
                }
                StripSwipeSections(
                    model: model,
                    header: "Strip Swipe",
                    choiceFooter: "Swipe left or right on the trackpad to slide the windows.",
                    testFooter:
                        "The swipe stays off until you test it and confirm that the strip followed your fingers. Settings > Gestures has the same controls later."
                )
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Done") { presenter?.close(.initialSetup) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 520, height: 720)
        .onAppear { model.refreshSetup() }
    }
}
