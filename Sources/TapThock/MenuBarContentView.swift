import SwiftUI

struct MenuBarContentView: View {
    @Bindable var appModel: AppModel
    @Bindable var permissionChecker: PermissionChecker

    init(appModel: AppModel) {
        self.appModel = appModel
        permissionChecker = appModel.permissionChecker
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Sound effects enabled", isOn: $appModel.isEnabled)
                .toggleStyle(.switch)

            if !permissionChecker.isTrusted {
                Label("Accessibility access is still required for global keyboard sounds.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(appModel.currentPackName)
                    .font(.headline)
                Text("Keyboard, mouse, and scroll sounds stay active even when TapThock is in the menu bar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("Preview") {
                    appModel.previewCurrentPack()
                }
                Button("Settings") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    DispatchQueue.main.async {
                        NSApp.windows.first { $0.title == "Settings" }?.makeKeyAndOrderFront(nil)
                    }
                }
            }

            Button("Onboarding") {
                appModel.showOnboarding()
            }

            if let statusMessage = appModel.statusMessage {
                Divider()
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button("Quit TapThock") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
