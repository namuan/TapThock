import SwiftUI

struct TapThockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let appModel = AppModel.shared

    var body: some Scene {
        MenuBarExtra("TapThock", systemImage: "keyboard") {
            MenuBarContentView(appModel: appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appModel: appModel)
                .frame(minWidth: 720, minHeight: 560)
        }
    }
}
