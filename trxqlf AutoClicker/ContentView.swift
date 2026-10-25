import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if !state.accessibilityTrusted {
                    permissionBanner
                }

                TabView {
                    MainTab()
                        .tabItem { Text("Clic auto") }
                    PositionsTab()
                        .tabItem { Text("Positions multiples") }
                    KeyHoldTab()
                        .tabItem { Text("Touche") }
                }
                .padding()
            }
            .frame(width: 400, height: 400)
        }
        .frame(width: 520, height: 580)
    }


    private var permissionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Autorisation d'Accessibilité requise pour cliquer et écouter les raccourcis.")
                .font(.caption)
            Spacer()
            Button("Autoriser") {
                state.checkAccessibilityPermission(prompt: true)
            }
            .font(.caption)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
    }
}

// MARK: - Onglet principal

struct MainTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section {
                Grid(horizontalSpacing: 15, verticalSpacing: 8) {
                    GridRow {
                        Text("Minutes :")
                            .foregroundColor(.white)
                            .gridColumnAlignment(.trailing) // Aligne tous les textes de cette colonne à droite
                        
                        TextField("", value: $state.minutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .gridColumnAlignment(.leading) // Aligne toutes les cases de cette colonne à gauche
                    }
                    
                    GridRow {
                        Text("Secondes :")
                            .foregroundColor(.white)
                        
                        TextField("", value: $state.seconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        
                    }
                    
                    GridRow {
                        Text("Millisecondes :")
                            .foregroundColor(.white)
                        
                        TextField("", value: $state.milliseconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Intervalle entre les clics")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }



            Section {
                Picker("Bouton", selection: $state.button) {
                    Text("Gauche").tag(ClickEngine.ClickButton.left)
                    Text("Droit").tag(ClickEngine.ClickButton.right)
                    Text("Milieu").tag(ClickEngine.ClickButton.middle)
                }
                .foregroundColor(.white)
                Picker("Type", selection: $state.clickType) {
                    Text("Simple").tag(ClickEngine.ClickType.single)
                    Text("Double").tag(ClickEngine.ClickType.double)
                }
                .foregroundColor(.white)
            } header: {
                Text("Options de clic")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            Section {
                Picker("", selection: $state.repeatUntilStopped) {
                    Text("Jusqu'à l'arrêt manuel").tag(true)
                    Text("Nombre de fois").tag(false)
                }
                .pickerStyle(.radioGroup)
                .foregroundColor(.white)

                if !state.repeatUntilStopped {
                    Stepper("Répéter \(state.repeatCount) fois", value: $state.repeatCount, in: 1...100000)
                        .foregroundColor(.white)
                }
            } header: {
                Text("Répétition")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            Section {
                Picker("", selection: $state.useCustomPositions) {
                    Text("Position actuelle du curseur").tag(false)
                    Text("Utiliser la liste de positions").tag(true)
                }
                .pickerStyle(.radioGroup)
                .foregroundColor(.white)
            } header: {
                Text("Position du curseur")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            // 5. RACCOURCIS
            Section {
                HotkeyRecorderView(title: "Démarrer / Arrêter", combo: state.startHotkey) {
                    state.updateStartHotkey($0)
                }

                HotkeyRecorderView(title: "Enregistrer une position", combo: state.recordHotkey) {
                    state.updateRecordHotkey($0)
                }

                Button("Réinitialiser (\(HotkeyCombo.startDefault.displayString) / \(HotkeyCombo.recordDefault.displayString) / \(HotkeyCombo.holdDefault.displayString))") {
                    state.resetHotkeysToDefaults()
                }
                .padding(.top, 4)
            } header: {
                Text("Raccourcis clavier")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }


            HStack {
                if state.isRunning {
                    Button("Arrêter") {
                        state.toggleClicking()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.1, green: 0.2, blue: 0.6))
                    .controlSize(.large)
                } else {
                    Button("Démarrer") {
                        state.toggleClicking()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.large)
                }

                Spacer()

                Text(state.statusText)
                    .foregroundColor(.white)
                    .font(.caption)
                    .shadow(color: .black.opacity(0.8), radius: 2)
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Onglet maintien de touche

/// Libellés d'un clavier AZERTY associés aux codes de touches physiques
/// (identiques aux positions d'un clavier QWERTY).
private struct AZERTYKey: Identifiable {
    let label: String
    let code: Int
    var id: Int { code }
}

private let azertyKeys: [AZERTYKey] = [
    AZERTYKey(label: "A", code: kVK_ANSI_Q),
    AZERTYKey(label: "B", code: kVK_ANSI_B),
    AZERTYKey(label: "C", code: kVK_ANSI_C),
    AZERTYKey(label: "D", code: kVK_ANSI_D),
    AZERTYKey(label: "E", code: kVK_ANSI_E),
    AZERTYKey(label: "F", code: kVK_ANSI_F),
    AZERTYKey(label: "G", code: kVK_ANSI_G),
    AZERTYKey(label: "H", code: kVK_ANSI_H),
    AZERTYKey(label: "I", code: kVK_ANSI_I),
    AZERTYKey(label: "J", code: kVK_ANSI_J),
    AZERTYKey(label: "K", code: kVK_ANSI_K),
    AZERTYKey(label: "L", code: kVK_ANSI_L),
    AZERTYKey(label: "M", code: kVK_ANSI_Semicolon),
    AZERTYKey(label: "N", code: kVK_ANSI_N),
    AZERTYKey(label: "O", code: kVK_ANSI_O),
    AZERTYKey(label: "P", code: kVK_ANSI_P),
    AZERTYKey(label: "Q", code: kVK_ANSI_A),
    AZERTYKey(label: "R", code: kVK_ANSI_R),
    AZERTYKey(label: "S", code: kVK_ANSI_S),
    AZERTYKey(label: "T", code: kVK_ANSI_T),
    AZERTYKey(label: "U", code: kVK_ANSI_U),
    AZERTYKey(label: "V", code: kVK_ANSI_V),
    AZERTYKey(label: "W", code: kVK_ANSI_Z),
    AZERTYKey(label: "X", code: kVK_ANSI_X),
    AZERTYKey(label: "Y", code: kVK_ANSI_Y),
    AZERTYKey(label: "Z", code: kVK_ANSI_W),
    AZERTYKey(label: "Espace", code: kVK_Space),
    AZERTYKey(label: "Maj", code: kVK_Shift),
    AZERTYKey(label: "Contrôle", code: kVK_Control),
    AZERTYKey(label: "Option", code: kVK_Option),
    AZERTYKey(label: "Tab", code: kVK_Tab),
    AZERTYKey(label: "Entrée", code: kVK_Return),
    AZERTYKey(label: "Échap", code: kVK_Escape),
    AZERTYKey(label: "←", code: kVK_LeftArrow),
    AZERTYKey(label: "→", code: kVK_RightArrow),
    AZERTYKey(label: "↓", code: kVK_DownArrow),
    AZERTYKey(label: "↑", code: kVK_UpArrow),
]

struct KeyHoldTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section {
                Picker("Touche (AZERTY)", selection: $state.holdKeyCode) {
                    ForEach(azertyKeys) { key in
                        Text(key.label).tag(key.code)
                    }
                }
                .foregroundColor(.white)
            } header: {
                Text("Touche à maintenir")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            Section {
                HotkeyRecorderView(title: "Maintenir / Relâcher", combo: state.holdHotkey) {
                    state.updateHoldHotkey($0)
                }
            } header: {
                Text("Raccourci clavier")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            Text("La touche reste enfoncée jusqu'à ce que tu appuies sur Relâcher, même si tu changes d'application. Le raccourci \(state.holdHotkey.displayString) marche aussi depuis le jeu.")
                .font(.caption)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 2)

            HStack {
                if state.isHoldingKey {
                    Button("Relâcher") {
                        state.toggleKeyHold()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.1, green: 0.2, blue: 0.6))
                    .controlSize(.large)
                } else {
                    Button("Maintenir") {
                        state.toggleKeyHold()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.large)
                }

                Spacer()

                Text(state.statusText)
                    .foregroundColor(.white)
                    .font(.caption)
                    .shadow(color: .black.opacity(0.8), radius: 2)
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Onglet positions multiples

struct PositionsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Place ton curseur où tu veux, puis appuie sur \(state.recordHotkey.displayString) (ou le bouton ci-dessous) pour enregistrer la position. L'appli cliquera ensuite sur chaque position dans l'ordre, en boucle.")
                .font(.caption)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 2)

            List {
                ForEach(Array(state.positions.enumerated()), id: \.offset) { index, point in
                    Text("\(index + 1). (\(Int(point.x)), \(Int(point.y)))")
                        .foregroundColor(.white)
                        .listRowBackground(Color.clear)
                }
                .onDelete { state.removePosition(at: $0) }
            }
            .scrollContentBackground(.hidden)
            .frame(minHeight: 220)

            HStack {
                Button("Enregistrer position (\(state.recordHotkey.displayString))") {
                    state.recordCurrentPosition()
                }
                Button("Tout effacer") {
                    state.clearPositions()
                }
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Enregistreur de raccourci clavier

/// Bouton qui, quand on clique dessus, attend la prochaine combinaison de
/// touches tapée par l'utilisateur (ex: ⌘P, ou une touche seule comme F9)
/// et la renvoie via `onChange`. Échap annule.
struct HotkeyRecorderView: View {
    let title: LocalizedStringKey
    let combo: HotkeyCombo
    var onChange: (HotkeyCombo) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(title)
                .fixedSize()
                .foregroundColor(.white)
            Spacer()
            Button(isRecording ? "Appuie sur une touche..." : combo.displayString) {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .frame(minWidth: 140)
            .foregroundColor(isRecording ? .accentColor : .white)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Échap annule l'enregistrement sans rien changer
            if UInt32(event.keyCode) == UInt32(kVK_Escape) {
                stopRecording()
                return nil
            }
            let newCombo = HotkeyCombo.from(event: event)
            onChange(newCombo)
            stopRecording()
            return nil // consomme l'évènement (pas de "bip" système)
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
