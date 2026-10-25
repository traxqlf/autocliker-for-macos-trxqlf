import Cocoa

/// Maintient une touche du clavier enfoncée en la réémettant régulièrement,
/// pour que le maintien suive l'application au premier plan.
final class KeyHoldEngine {

    private var timer: Timer?
    private var keyCode: CGKeyCode?
    private var terminateObserver: NSObjectProtocol?

    init() {
        // Relâche la touche si l'appli quitte pendant un maintien.
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    func start(keyCode: CGKeyCode) {
        guard timer == nil else { return }
        self.keyCode = keyCode

        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.postKey(down: true)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        postKey(down: false)
        keyCode = nil
    }

    private func postKey(down: Bool) {
        guard let keyCode else { return }
        // Ne pas envoyer la touche à notre propre fenêtre (Retour/Espace
        // pourraient actionner le bouton).
        if down, NSApp?.isActive == true { return }

        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down)
        event?.post(tap: .cghidEventTap)
    }

    deinit {
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }
}
