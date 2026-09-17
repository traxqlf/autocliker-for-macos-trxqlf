import SwiftUI

@main
struct AutoClickerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(width: 420, height: 580)
                .fixedSize()
        }
        .windowResizability(.contentSize)
    }
}
