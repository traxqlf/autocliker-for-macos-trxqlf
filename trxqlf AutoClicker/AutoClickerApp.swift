import SwiftUI

@main
struct AutoClickerApp: App {
    @StateObject private var state = AppState()
    @StateObject private var updater = UpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(updater)
                .frame(width: 520, height: 580)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Rechercher des mises à jour…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}
