import Cocoa

/// Simule les clics souris via CGEvent et gère la boucle de répétition.
final class ClickEngine {

    enum ClickButton {
        case left, right, middle
    }

    enum ClickType {
        case single, double
    }

    enum RepeatMode {
        case infinite
        case count(Int)
    }

    enum PositionMode {
        case current
        case list([CGPoint])
    }

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.autoclicker.engine")
    private(set) var isRunning = false

    /// Appelé sur le thread principal quand la boucle se termine d'elle-même
    /// (mode "nombre de fois" arrivé à son terme).
    var onFinished: (() -> Void)?

    func start(interval: TimeInterval,
               button: ClickButton,
               clickType: ClickType,
               repeatMode: RepeatMode,
               positionMode: PositionMode) {
        guard !isRunning else { return }
        isRunning = true

        var done = 0
        var posIndex = 0
        var positions: [CGPoint] = []
        if case .list(let pts) = positionMode {
            positions = pts
        }

        let t = DispatchSource.makeTimerSource(queue: queue)
        // interval minimum pour éviter une boucle folle si l'utilisateur met 0
        let safeInterval = max(interval, 0.001)
        t.schedule(deadline: .now(), repeating: safeInterval)

        t.setEventHandler { [weak self] in
            guard let self = self else { return }

            var point: CGPoint? = nil
            if !positions.isEmpty {
                point = positions[posIndex % positions.count]
                posIndex += 1
            }
            self.performClick(at: point, button: button, clickType: clickType)

            done += 1
            if case .count(let target) = repeatMode, done >= target {
                self.stop()
                DispatchQueue.main.async { self.onFinished?() }
            }
        }

        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    /// Enregistre la position actuelle du curseur, en coordonnées CG
    /// (origine en haut à gauche), utilisables directement pour un clic.
    static func currentCursorPositionCG() -> CGPoint {
        let mouseLoc = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)
    }

    private func performClick(at point: CGPoint?, button: ClickButton, clickType: ClickType) {
        let location = point ?? ClickEngine.currentCursorPositionCG()

        let (downType, upType, cgButton): (CGEventType, CGEventType, CGMouseButton) = {
            switch button {
            case .left: return (.leftMouseDown, .leftMouseUp, .left)
            case .right: return (.rightMouseDown, .rightMouseUp, .right)
            case .middle: return (.otherMouseDown, .otherMouseUp, .center)
            }
        }()

        // Si on clique à une position précise, on déplace d'abord le curseur.
        if point != nil {
            let move = CGEvent(mouseEventSource: nil,
                                mouseType: .mouseMoved,
                                mouseCursorPosition: location,
                                mouseButton: .left)
            move?.post(tap: .cghidEventTap)
            usleep(10_000) // 10 ms, laisse le système prendre en compte le déplacement
        }

        let clicks = clickType == .double ? 2 : 1
        for i in 1...clicks {
            let down = CGEvent(mouseEventSource: nil,
                                mouseType: downType,
                                mouseCursorPosition: location,
                                mouseButton: cgButton)
            down?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            down?.post(tap: .cghidEventTap)

            let up = CGEvent(mouseEventSource: nil,
                              mouseType: upType,
                              mouseCursorPosition: location,
                              mouseButton: cgButton)
            up?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            up?.post(tap: .cghidEventTap)

            
            }
        }
    }
