import Cocoa
import Carbon.HIToolbox
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Groupe de positions sauvegardé sous un nom, réutilisable plus tard.
struct PositionGroup: Codable, Identifiable {
    var id = UUID()
    var name: String
    var positions: [CGPoint]
}

final class AppState: ObservableObject {

    // Intervalle sauvegardé
    @AppStorage("savedMinutes") var minutes: Int = 0
    @AppStorage("savedSeconds") var seconds: Int = 0
    @AppStorage("savedMilliseconds") var milliseconds: Int = 100

    // Options de clic (persistées)
    @AppStorage("savedClickButton") var button: ClickEngine.ClickButton = .left
    @AppStorage("savedClickType") var clickType: ClickEngine.ClickType = .single

    // Choix de la langue
    @AppStorage("appLanguage") var language: String = "fr"
    
    // Répétition sauvegardée
    @AppStorage("savedRepeatMode") var repeatUntilStopped: Bool = true
    @AppStorage("savedRepeatCount") var repeatCount: Int = 10

    // Position sauvegardée
    @AppStorage("savedUsePositions") var useCustomPositions: Bool = false
    @Published var positions: [CGPoint] = []

    // Groupes de positions sauvegardés
    @Published var positionGroups: [PositionGroup] = []
    private let positionGroupsKey = "autoclicker.positionGroups"

    // Maintien de touche (code physique : kVK_ANSI_W correspond à Z en AZERTY)
    @AppStorage("savedHoldKeyCode") var holdKeyCode: Int = kVK_ANSI_W
    @Published var isHoldingKey: Bool = false

    // Raccourcis (configurables, persistés dans UserDefaults)
    @Published private(set) var startHotkey: HotkeyCombo = .startDefault
    @Published private(set) var recordHotkey: HotkeyCombo = .recordDefault
    @Published private(set) var holdHotkey: HotkeyCombo = .holdDefault

    // Fond d'écran choisi par l'utilisateur (copié dans le conteneur sandbox)
    @Published var backgroundImage: NSImage?
    @Published var pendingBackgroundImage: NSImage?
    @AppStorage("backgroundDim") var backgroundDim: Double = 0
    @AppStorage("backgroundBlur") var backgroundBlur: Double = 0

    // État
    @Published var isRunning: Bool = false
    // ⬇️ MODIFIÉ ICI
    @Published var statusText: String = String(localized: "Prêt")
    @Published var accessibilityTrusted: Bool = false

    private let engine = ClickEngine()
    private let keyHoldEngine = KeyHoldEngine()
    private let hotkeyManager = HotkeyManager()
    private let defaults = UserDefaults.standard
    private let startHotkeyKey = "autoclicker.startHotkey"
    private let recordHotkeyKey = "autoclicker.recordHotkey"
    private let holdHotkeyKey = "autoclicker.holdHotkey"

    private var customBackgroundURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("trxqlf AutoClicker/backgroundImage")
    }

    func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let image = NSImage(contentsOf: url) else { return }
        pendingBackgroundImage = image
    }

    func saveCroppedBackground(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            statusText = "Image non chargée"
            return
        }
        do {
            try FileManager.default.createDirectory(at: customBackgroundURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try png.write(to: customBackgroundURL)
            backgroundImage = image
            pendingBackgroundImage = nil
        } catch {
            statusText = "Image non chargée"
        }
    }

    func useDefaultBackground() {
        try? FileManager.default.removeItem(at: customBackgroundURL)
        backgroundImage = nil
    }

    init() {
        backgroundImage = NSImage(contentsOf: customBackgroundURL)
        // Les positions ne sont pas persistées : au lancement la liste est vide,
        // donc on repart sur le curseur au lieu de bloquer le démarrage.
        if positions.isEmpty { useCustomPositions = false }
        loadPositionGroups()

        checkAccessibilityPermission(prompt: false)
        loadPersistedHotkeys()
        registerStartHotkey()
        registerRecordHotkey()
        registerHoldHotkey()

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
        if let data = defaults.data(forKey: holdHotkeyKey),
           let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            holdHotkey = combo
        }
    }

    private func persistHotkeys() {
        if let data = try? JSONEncoder().encode(startHotkey) {
            defaults.set(data, forKey: startHotkeyKey)
        }
        if let data = try? JSONEncoder().encode(recordHotkey) {
            defaults.set(data, forKey: recordHotkeyKey)
        }
        if let data = try? JSONEncoder().encode(holdHotkey) {
            defaults.set(data, forKey: holdHotkeyKey)
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

    private func registerHoldHotkey() {
        hotkeyManager.setHotkey(role: "hold", combo: holdHotkey) { [weak self] in
            self?.toggleKeyHold()
        }
    }

    @discardableResult
    func updateStartHotkey(_ combo: HotkeyCombo) -> Bool {
        guard combo != recordHotkey else {
            // ⬇️ MODIFIÉ ICI
            statusText = String(localized: "Ce raccourci est déjà utilisé pour l'enregistrement de position")
            return false
        }
        guard combo != holdHotkey else {
            statusText = String(localized: "Ce raccourci est déjà utilisé pour le maintien de touche")
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
        guard combo != holdHotkey else {
            statusText = String(localized: "Ce raccourci est déjà utilisé pour le maintien de touche")
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

    @discardableResult
    func updateHoldHotkey(_ combo: HotkeyCombo) -> Bool {
        guard combo != startHotkey else {
            statusText = String(localized: "Ce raccourci est déjà utilisé pour démarrer/arrêter")
            return false
        }
        guard combo != recordHotkey else {
            statusText = String(localized: "Ce raccourci est déjà utilisé pour l'enregistrement de position")
            return false
        }
        let previous = holdHotkey
        holdHotkey = combo
        guard hotkeyManager.setHotkey(role: "hold", combo: combo, handler: { [weak self] in
            self?.toggleKeyHold()
        }) else {
            holdHotkey = previous
            registerHoldHotkey()
            statusText = String(localized: "Ce raccourci est déjà utilisé par une autre application")
            return false
        }
        persistHotkeys()
        statusText = String(localized: "Raccourci maintien de touche : \(combo.displayString)")
        return true
    }

    func resetHotkeysToDefaults() {
        // Assignation directe (sans le garde anti-doublon des update*),
        // pour que le reset marche même si les touches ont été inversées.
        startHotkey = .startDefault
        recordHotkey = .recordDefault
        holdHotkey = .holdDefault
        registerStartHotkey()
        registerRecordHotkey()
        registerHoldHotkey()
        persistHotkeys()
        statusText = String(localized: "Raccourcis réinitialisés : \(HotkeyCombo.startDefault.displayString) / \(HotkeyCombo.recordDefault.displayString) / \(HotkeyCombo.holdDefault.displayString)")
    }

    // MARK: - Positions

    func recordCurrentPosition() {
        let point = ClickEngine.currentCursorPositionCG()
        positions.append(point)
        // Enregistrer un point implique de cliquer sur la liste, pas au curseur.
        useCustomPositions = true
        // ⬇️ MODIFIÉ ICI
        statusText = String(localized: "Position enregistrée : (\(Int(point.x)), \(Int(point.y)))")
    }

    private var delayedRecord: DispatchWorkItem?

    /// Laisse le temps de déplacer le curseur avant d'enregistrer le point.
    func recordCurrentPositionAfterDelay(_ delay: TimeInterval = 3) {
        delayedRecord?.cancel()
        statusText = String(localized: "Place ton curseur sur le point à ajouter…")
        let work = DispatchWorkItem { [weak self] in
            self?.recordCurrentPosition()
            self?.delayedRecord = nil
        }
        delayedRecord = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func movePositionUp(_ index: Int) {
        guard index > 0, index < positions.count else { return }
        positions.swapAt(index, index - 1)
    }

    func movePositionDown(_ index: Int) {
        guard index >= 0, index < positions.count - 1 else { return }
        positions.swapAt(index, index + 1)
    }

    func removePosition(at offsets: IndexSet) {
        positions.remove(atOffsets: offsets)
        if positions.isEmpty { useCustomPositions = false }
    }

    func clearPositions() {
        positions.removeAll()
        useCustomPositions = false
    }

    // MARK: - Groupes de positions

    private func loadPositionGroups() {
        guard let data = defaults.data(forKey: positionGroupsKey),
              let groups = try? JSONDecoder().decode([PositionGroup].self, from: data) else { return }
        positionGroups = groups
    }

    private func persistPositionGroups() {
        if let data = try? JSONEncoder().encode(positionGroups) {
            defaults.set(data, forKey: positionGroupsKey)
        }
    }

    /// Sauvegarde la liste actuelle. Un nom existant met à jour le groupe.
    func saveCurrentPositionsAsGroup(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !positions.isEmpty else { return }

        if let index = positionGroups.firstIndex(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            positionGroups[index].positions = positions
            statusText = String(localized: "Groupe « \(trimmed) » mis à jour")
        } else {
            positionGroups.append(PositionGroup(name: trimmed, positions: positions))
            statusText = String(localized: "Groupe « \(trimmed) » enregistré")
        }
        persistPositionGroups()
    }

    func loadGroup(_ group: PositionGroup) {
        positions = group.positions
        useCustomPositions = true
        statusText = String(localized: "Groupe « \(group.name) » chargé")
    }

    func deleteGroup(_ group: PositionGroup) {
        positionGroups.removeAll { $0.id == group.id }
        persistPositionGroups()
        statusText = String(localized: "Groupe « \(group.name) » supprimé")
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

        checkAccessibilityPermission(prompt: !accessibilityTrusted)
        if !accessibilityTrusted {
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

    // MARK: - Maintien de touche

    func toggleKeyHold() {
        if isHoldingKey {
            stopKeyHold()
        } else {
            startKeyHold()
        }
    }

    func startKeyHold() {
        guard !isHoldingKey else { return }

        checkAccessibilityPermission(prompt: !accessibilityTrusted)
        if !accessibilityTrusted {
            statusText = String(localized: "Autorisation d'Accessibilité requise (voir Réglages Système)")
            return
        }

        keyHoldEngine.start(keyCode: CGKeyCode(holdKeyCode))
        isHoldingKey = true
        statusText = String(localized: "Touche maintenue")
    }

    func stopKeyHold() {
        keyHoldEngine.stop()
        isHoldingKey = false
        statusText = String(localized: "Touche relâchée")
    }
}
