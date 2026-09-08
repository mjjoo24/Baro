import BaroCore
import SwiftUI

@main
struct BaroApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appModel)
        } label: {
            Image(systemName: menuBarIconName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
    }

    private var menuBarIconName: String {
        switch appModel.monitor.state {
        case .good: return "figure.stand"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}
