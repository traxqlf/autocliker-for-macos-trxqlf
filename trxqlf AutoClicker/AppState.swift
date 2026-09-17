import Cocoa
import Carbon.HIToolbox
import Combine
import SwiftUI

final class AppState: ObservableObject {

    // Intervalle sauvegardé
    @AppStorage("savedMinutes") var minutes: Int = 0
    @AppStorage("savedSeconds") var seconds: Int = 0
    @AppStorage("savedMilliseconds") var milliseconds: Int = 100

    // Options de clic
    @Published var button: ClickEngine.ClickButton = .left
    @Published var clickType: ClickEngine.ClickType = .single

    // Choix de la langue
    @AppStorage("appLanguage") var language: String = "fr"
    
    // Répétition sauvegardée
    @AppStorage("savedRepeatMode") var repeatUntilStopped: Bool = true
    @AppStorage("savedRepeatCount") var repeatCount: Int = 10

    // Position sauvegardée
    @AppStorage("savedUsePositions") var useCustomPositions: Bool = false
    @Published var positions: [CGPoint] = []

    // Raccourcis (configurables, persistés dans UserDefaults)
    @Published private(set) var startHotkey: HotkeyCombo = .startDefault
    @Published private(set) var recordHotkey: HotkeyCombo = .recordDefault

    // État
    @Published var isRunning: Bool = false
    // ⬇️ MODIFIÉ ICI
    @Published var statusText: String = String(localized: "Prêt")
    @Published var accessibilityTrusted: Bool = false

    private let engine = ClickEngine()
    private let hotkeyManager = HotkeyManager()
    private let defaults = UserDefaults.standard
    private let startHotkeyKey = "autoclicker.startHotkey"
    private let recordHotkeyKey = "autoclicker.recordHotkey"

    init() {
        checkAccessibilityPermission(prompt: false)
        loadPersistedHotkeys()
        registerStartHotkey()
        registerRecordHotkey()

        engine.onFinished = { [weak self] in
            self?.isRunning = false
            // ⬇️ MODIFIÉ ICI
            self?.statusText = String(localized: "Terminé")
        }
    }

    // MARK: - Permissions

    func checkAccessibilityPermission(prompt: Bool) {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Raccourcis configurables

    private func loadPersistedHotkeys() {
        if let data = defaults.data(forKey: startHotkeyKey),
           let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            startHotkey = combo
        }
        if let data = defaults.data(forKey: recordHotkeyKey),
           let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            recordHotkey = combo
        }
    }

    private func persistHotkeys() {
        if let data = try? JSONEncoder().encode(startHotkey) {
            defaults.set(data, forKey: startHotkeyKey)
        }
        if let data = try? JSONEncoder().encode(recordHotkey) {
            defaults.set(data, forKey: recordHotkeyKey)
        }
    }

    private func registerStartHotkey() {
        hotkeyManager.setHotkey(role: "start", combo: startHotkey) { [weak self] in
            self?.toggleClicking()
        }
    }

    private func registerRecordHotkey() {
        hotkeyManager.setHotkey(role: "record", combo: recordHotkey) { [weak self] in
            self?.recordCurrentPosition()
        }
    }

    @discardableResult
    func updateStartHotkey(_ combo: HotkeyCombo) -> Bool {
        guard combo != recordHotkey else {
            // ⬇️ MODIFIÉ ICI
            statusText = String(localized: "Ce raccourci est déjà utilisé pour l'enregistrement de position")
            return false
        }
        let previous = startHotkey
        startHotkey = combo
        guard hotkeyManager.setHotkey(role: "start", combo: combo, handler: { [weak self] in
            self?.toggleClicking()
        }) else {
            startHotkey = previous
            registerStartHotkey()
            // ⬇️ MODIFIÉ ICI
            statusText = String(localized: "Ce raccourci est déjà utilisé par une autre application")
            return false
        }
        persistHotkeys()
        // ⬇️ MODIFIÉ ICI (Gère parfaitement l'interpolation de la variable)
        statusText = String(localized: "Raccourci démarrer/arrêter : \(combo.displayString)")
        return true
    }

    @discardableResult
    func updateRecordHotkey(_ combo: HotkeyCombo) -> Bool {
        guard combo != startHotkey else {
            // ⬇️ MODIFIÉ ICI
            statusText = String(localized: "Ce raccourci est déjà utilisé pour démarrer/arrêter")
            return false
        }
        let previous = recordHotkey
        recordHotkey = combo
        guard hotkeyManager.setHotkey(role: "record", combo: combo, handler: { [weak self] in
            self?.recordCurrentPosition()
        }) else {
            recordHotkey = previous
            registerRecordHotkey()
            // ⬇️ MODIFIÉ ICI
            statusText = String(localized: "Ce raccourci est déjà utilisé par une autre application")
            return false
        }
        persistHotkeys()
        // ⬇️ MODIFIÉ ICI
        statusText = String(localized: "Raccourci enregistrer position : \(combo.displayString)")
        return true
    }

    func resetHotkeysToDefaults() {
        updateStartHotkey(.startDefault)
        updateRecordHotkey(.recordDefault)
    }

    // MARK: - Positions

    func recordCurrentPosition() {
        let point = ClickEngine.currentCursorPositionCG()
        positions.append(point)
        // ⬇️ MODIFIÉ ICI
        statusText = String(localized: "Position enregistrée : (\(Int(point.x)), \(Int(point.y)))")
    }

    func removePosition(at offsets: IndexSet) {
        positions.remove(atOffsets: offsets)
    }

    func clearPositions() {
        positions.removeAll()
    }

    // MARK: - Clic

    var intervalSeconds: TimeInterval {
        TimeInterval(minutes) * 60
            + TimeInterval(seconds)
            + TimeInterval(milliseconds) / 1000.0
    }

    func toggleClicking() {
        if isRunning {
            stopClicking()
        } else {
            startClicking()
        }
    }

    func startClicking() {
        guard !isRunning else { return }

        if !accessibilityTrusted {
            checkAccessibilityPermission(prompt: true)
            // ⬇️ MODIFIÉ ICI
            statusText = String(localized: "Autorisation d'Accessibilité requise (voir Réglages Système)")
            return
        }

        if useCustomPositions && positions.isEmpty {
            // ⬇️ MODIFIÉ ICI
            statusText = String(localized: "Ajoute au moins une position avant de démarrer")
            return
        }

        let repeatMode: ClickEngine.RepeatMode = repeatUntilStopped ? .infinite : .count(max(repeatCount, 1))
        let positionMode: ClickEngine.PositionMode = useCustomPositions ? .list(positions) : .current

        engine.start(interval: intervalSeconds,
                      button: button,
                      clickType: clickType,
                      repeatMode: repeatMode,
                      positionMode: positionMode)

        isRunning = true
        // ⬇️ MODIFIÉ ICI
        statusText = String(localized: "En cours…")
    }

    func stopClicking() {
        engine.stop()
        isRunning = false
        // ⬇️ MODIFIÉ ICI
        statusText = String(localized: "Arrêté")
    }
}
