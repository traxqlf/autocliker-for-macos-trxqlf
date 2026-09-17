import Carbon.HIToolbox
import Cocoa

/// Gère des raccourcis clavier globaux (actifs même quand l'appli n'a pas le
/// focus) via l'API Carbon RegisterEventHotKey. Chaque raccourci est identifié
/// par un "rôle" (ex: "start", "record") et peut être remplacé à tout moment
/// (ré-enregistré avec une nouvelle combinaison) sans redémarrer l'appli.
final class HotkeyManager {

    typealias Handler = () -> Void

    private struct Registration {
        var ref: EventHotKeyRef?
        var handler: Handler
    }

    private var registrations: [UInt32: Registration] = [:]
    private var roleToID: [String: UInt32] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: OSType(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData = userData, let eventRef = eventRef else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                GetEventParameter(eventRef,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)

                manager.registrations[hotKeyID.id]?.handler()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    /// Enregistre (ou remplace) le raccourci associé à `role` avec le combo
    /// donné. Si `role` avait déjà un raccourci enregistré, l'ancien est
    /// désenregistré au préalable.
    @discardableResult
    func setHotkey(role: String, combo: HotkeyCombo, handler: @escaping Handler) -> Bool {
        unregister(role: role)

        var hotKeyRef: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x41434C4B), id: nextID) // 'ACLK'
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { return false }

        registrations[nextID] = Registration(ref: hotKeyRef, handler: handler)
        roleToID[role] = nextID
        nextID += 1
        return true
    }

    func unregister(role: String) {
        guard let id = roleToID[role], let reg = registrations[id] else { return }
        if let ref = reg.ref { UnregisterEventHotKey(ref) }
        registrations.removeValue(forKey: id)
        roleToID.removeValue(forKey: role)
    }

    func unregisterAll() {
        for (_, reg) in registrations {
            if let ref = reg.ref { UnregisterEventHotKey(ref) }
        }
        registrations.removeAll()
        roleToID.removeAll()
    }

    deinit {
        unregisterAll()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
