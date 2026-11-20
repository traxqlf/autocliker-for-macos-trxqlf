import Combine
import Sparkle

/// Encapsule Sparkle et expose l'état du vérificateur de mises à jour à SwiftUI.
@MainActor
final class UpdaterController: ObservableObject {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    @Published private(set) var canCheckForUpdates = false

    private var cancellable: AnyCancellable?

    init() {
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
