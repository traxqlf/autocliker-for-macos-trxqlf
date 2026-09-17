import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !state.accessibilityTrusted {
                permissionBanner
            }
            
            TabView {
                MainTab()
                    .tabItem { Text("Clic auto") }
                PositionsTab()
                    .tabItem { Text("Positions multiples") }
            }
            .padding()
        }
        .frame(width: 400, height: 400)
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
                            .gridColumnAlignment(.trailing) // Aligne tous les textes de cette colonne à droite
                        
                        TextField("", value: $state.minutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .gridColumnAlignment(.leading) // Aligne toutes les cases de cette colonne à gauche
                    }
                    
                    GridRow {
                        Text("Secondes :")
                        
                        TextField("", value: $state.seconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        
                    }
                    
                    GridRow {
                        Text("Millisecondes :")
                        
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
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }



            Section {
                Picker("Bouton", selection: $state.button) {
                    Text("Gauche").tag(ClickEngine.ClickButton.left)
                    Text("Droit").tag(ClickEngine.ClickButton.right)
                    Text("Milieu").tag(ClickEngine.ClickButton.middle)
                }
                Picker("Type", selection: $state.clickType) {
                    Text("Simple").tag(ClickEngine.ClickType.single)
                    Text("Double").tag(ClickEngine.ClickType.double)
                }
            } header: {
                Text("Options de clic")
                    .font(.headline)
                    .bold()
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            Section {
                Picker("", selection: $state.repeatUntilStopped) {
                    Text("Jusqu'à l'arrêt manuel").tag(true)
                    Text("Nombre de fois").tag(false)
                }
                .pickerStyle(.radioGroup)

                if !state.repeatUntilStopped {
                    Stepper("Répéter \(state.repeatCount) fois", value: $state.repeatCount, in: 1...100000)
                }
            } header: {
                Text("Répétition")
                    .font(.headline)
                    .bold()
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            Section {
                Picker("", selection: $state.useCustomPositions) {
                    Text("Position actuelle du curseur").tag(false)
                    Text("Utiliser la liste de positions").tag(true)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Position du curseur")
                    .font(.headline)
                    .bold()
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

                Button("Réinitialiser (\(HotkeyCombo.startDefault.displayString) / \(HotkeyCombo.recordDefault.displayString))") {
                    state.resetHotkeysToDefaults()
                }
                .padding(.top, 4)
            } header: {
                Text("Raccourcis clavier")
                    .font(.headline)
                    .bold()
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
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Onglet positions multiples

struct PositionsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Place ton curseur où tu veux, puis appuie sur \(state.recordHotkey.displayString) (ou le bouton ci-dessous) pour enregistrer la position. L'appli cliquera ensuite sur chaque position dans l'ordre, en boucle.")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(Array(state.positions.enumerated()), id: \.offset) { index, point in
                    Text("\(index + 1). (\(Int(point.x)), \(Int(point.y)))")
                }
                .onDelete { state.removePosition(at: $0) }
            }
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
            Spacer()
            Button(isRecording ? "Appuie sur une touche..." : combo.displayString) {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .frame(minWidth: 140)
            .foregroundColor(isRecording ? .accentColor : .primary)
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
