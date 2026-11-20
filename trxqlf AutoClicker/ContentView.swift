import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                if !state.accessibilityTrusted {
                    permissionBanner
                }

                TabView {
                    MainTab()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .tabItem { Text("Clic auto") }
                    PositionsTab()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .tabItem { Text("Positions") }
                    KeyHoldTab()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .tabItem { Text("Touche") }
                    SettingsTab()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .tabItem { Text("Réglages") }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .toolbarBackground(.hidden, for: .windowToolbar)
            }
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
        }
        .frame(width: 520, height: 580)
        .sheet(isPresented: Binding(
            get: { state.pendingBackgroundImage != nil },
            set: { if !$0 { state.pendingBackgroundImage = nil } }
        )) {
            if let image = state.pendingBackgroundImage {
                BackgroundCropView(
                    image: image,
                    onValidate: { state.saveCroppedBackground($0) },
                    onCancel: { state.pendingBackgroundImage = nil }
                )
            }
        }
    }

    private var background: some View {
        GeometryReader { geo in
            Group {
                if let image = state.backgroundImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
                        .blur(radius: state.backgroundBlur)
                        .overlay(Color.black.opacity(state.backgroundDim))
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.12), .clear, .black.opacity(0.22)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Fond natif : blanc en mode clair, noir en mode sombre.
                    Color(nsColor: .textBackgroundColor)
                }
            }
            .clipped()
        }
        .ignoresSafeArea()
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text("Autorisation d'Accessibilité requise pour cliquer et écouter les raccourcis.")
                .font(.caption)
                .foregroundColor(.primary)
            Spacer(minLength: 8)
            Button("Autoriser") {
                state.checkAccessibilityPermission(prompt: true)
            }
            .font(.caption)
            .glassButton()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 14)
        .padding(.horizontal, 14)
        .padding(.top, 48)
    }
}

/// État partagé affiché en bas de la fenêtre.
struct StatusFooter: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.isRunning || state.isHoldingKey ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            Text(state.statusText)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassCapsule()
    }
}

// MARK: - Onglet principal

struct MainTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    GlassSection("Intervalle entre les clics") {
                        Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text("Minutes")
                                    .foregroundColor(.primary)
                                    .gridColumnAlignment(.trailing)
                                TextField("", value: $state.minutes, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 72)
                                    .gridColumnAlignment(.leading)
                            }
                            GridRow {
                                Text("Secondes")
                                    .foregroundColor(.primary)
                                TextField("", value: $state.seconds, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 72)
                            }
                            GridRow {
                                Text("Millisecondes")
                                    .foregroundColor(.primary)
                                TextField("", value: $state.milliseconds, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 72)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    GlassSection("Options de clic") {
                        SettingRow("Bouton") {
                            Picker("", selection: $state.button) {
                                Text("Gauche").tag(ClickEngine.ClickButton.left)
                                Text("Droit").tag(ClickEngine.ClickButton.right)
                                Text("Milieu").tag(ClickEngine.ClickButton.middle)
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        SettingRow("Type") {
                            Picker("", selection: $state.clickType) {
                                Text("Simple").tag(ClickEngine.ClickType.single)
                                Text("Double").tag(ClickEngine.ClickType.double)
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                    }

                    GlassSection("Répétition") {
                        Picker("", selection: $state.repeatUntilStopped) {
                            Text("Jusqu'à l'arrêt manuel").tag(true)
                            Text("Nombre de fois").tag(false)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .foregroundColor(.primary)

                        if !state.repeatUntilStopped {
                            SettingRow("Répéter") {
                                Stepper("\(state.repeatCount) fois", value: $state.repeatCount, in: 1...100000)
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    GlassSection("Raccourcis clavier") {
                        HotkeyRecorderView(title: "Démarrer / Arrêter", combo: state.startHotkey) {
                            state.updateStartHotkey($0)
                        }

                        HotkeyRecorderView(title: "Enregistrer une position", combo: state.recordHotkey) {
                            state.updateRecordHotkey($0)
                        }

                        Button("Réinitialiser les raccourcis") {
                            state.resetHotkeysToDefaults()
                        }
                        .font(.caption)
                        .glassButton()
                        .help("Défauts : \(HotkeyCombo.startDefault.displayString), \(HotkeyCombo.recordDefault.displayString), \(HotkeyCombo.holdDefault.displayString)")
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button(state.isRunning ? "Arrêter" : "Démarrer") {
                    state.toggleClicking()
                }
                .keyboardShortcut(.defaultAction)
                .tint(state.isRunning ? .red : .blue)
                .controlSize(.large)
                .glassButton(prominent: true)

                Spacer()
                StatusFooter()
            }
            .padding(.top, 8)
        }
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
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    GlassSection("Touche à maintenir") {
                        SettingRow("Touche (AZERTY)") {
                            Picker("", selection: $state.holdKeyCode) {
                                ForEach(azertyKeys) { key in
                                    Text(key.label).tag(key.code)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                    }

                    GlassSection("Raccourci clavier") {
                        HotkeyRecorderView(title: "Maintenir / Relâcher", combo: state.holdHotkey) {
                            state.updateHoldHotkey($0)
                        }
                    }

                    Text("La touche reste enfoncée jusqu'à ce que tu appuies sur Relâcher, même si tu changes d'application. Le raccourci \(state.holdHotkey.displayString) marche aussi depuis le jeu.")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button(state.isHoldingKey ? "Relâcher" : "Maintenir") {
                    state.toggleKeyHold()
                }
                .keyboardShortcut(.defaultAction)
                .tint(state.isHoldingKey ? .red : .blue)
                .controlSize(.large)
                .glassButton(prominent: true)

                Spacer()
                StatusFooter()
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Onglet positions multiples

struct PositionsTab: View {
    @EnvironmentObject var state: AppState
    @State private var confirmClear = false
    @State private var showSaveGroup = false
    @State private var groupName = ""

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Points de clic automatique")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.primary)
                Text("Ajoute des points, puis réordonne-les : l'appli cliquera dessus dans cet ordre, en boucle.")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Toggle("Utiliser ces points", isOn: $state.useCustomPositions)
                    .toggleStyle(.switch)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(state.positions.count) point\(state.positions.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Groupes enregistrés")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary.opacity(0.85))
                    Spacer()
                    Button {
                        groupName = "Groupe \(state.positionGroups.count + 1)"
                        showSaveGroup = true
                    } label: {
                        Label("Enregistrer", systemImage: "square.and.arrow.down")
                    }
                    .font(.caption)
                    .glassButton()
                    .disabled(state.positions.isEmpty)
                    .help("Sauvegarde la liste actuelle pour la réutiliser plus tard")
                }

                if state.positionGroups.isEmpty {
                    Text("Aucun groupe enregistré.")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.positionGroups) { group in
                                HStack(spacing: 6) {
                                    Button {
                                        state.loadGroup(group)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(group.name)
                                                .font(.caption)
                                                .bold()
                                            Text("\(group.positions.count) point\(group.positions.count > 1 ? "s" : "")")
                                                .font(.caption2)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help("Charger ce groupe")

                                    Button {
                                        state.deleteGroup(group)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Supprimer ce groupe")
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .glassCapsule()
                            }
                        }
                    }
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 14)

            if state.positions.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(Array(state.positions.enumerated()), id: \.offset) { index, point in
                            positionRow(index: index, point: point)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)
            }

            HStack(spacing: 8) {
                Button {
                    state.recordCurrentPositionAfterDelay()
                } label: {
                    Label("Ajouter un point (3 s)", systemImage: "plus.circle.fill")
                }
                .tint(.blue)
                .controlSize(.large)
                .glassButton(prominent: true)

                if !state.positions.isEmpty {
                    Button("Tout effacer") {
                        confirmClear = true
                    }
                    .foregroundColor(.primary)
                    .glassButton()
                }

                Spacer()
                StatusFooter()
            }
            .padding(.top, 2)
        }
        .confirmationDialog("Effacer tous les points ?", isPresented: $confirmClear) {
            Button("Tout effacer", role: .destructive) { state.clearPositions() }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("La liste sera vidée définitivement.")
        }
        .alert("Enregistrer le groupe", isPresented: $showSaveGroup) {
            TextField("Nom du groupe", text: $groupName)
            Button("Enregistrer") { state.saveCurrentPositionsAsGroup(named: groupName) }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("La liste actuelle sera sauvegardée sous ce nom. Un nom déjà utilisé sera mis à jour.")
        }
    }

    private func positionRow(index: Int, point: CGPoint) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 1) {
                Text("Point \(index + 1)")
                    .font(.callout)
                    .foregroundColor(.primary)
                Text("x \(Int(point.x))   y \(Int(point.y))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.primary)
            }

            Spacer()

            Button {
                state.movePositionUp(index)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)
            .disabled(index == 0)
            .help("Monter")

            Button {
                state.movePositionDown(index)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)
            .disabled(index == state.positions.count - 1)
            .help("Descendre")

            Button {
                state.removePosition(at: IndexSet(integer: index))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.primary)
            .help("Supprimer ce point")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassCard(cornerRadius: 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 30))
                .foregroundColor(.primary)
            Text("Aucun point enregistré")
                .font(.callout)
                .bold()
                .foregroundColor(.primary)
            Text("Clique sur « Ajouter un point (3 s) », place ton curseur sur la zone voulue, puis attends l'enregistrement.")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Onglet réglages

struct SettingsTab: View {
    @EnvironmentObject var state: AppState

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                GlassSection("Fond d'écran") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Choisir une image de fond…") {
                            state.chooseBackgroundImage()
                        }
                        .glassButton()

                        if state.backgroundImage != nil {
                            Button("Revenir au fond par défaut") {
                                state.useDefaultBackground()
                            }
                            .glassButton()
                        }
                    }

                    SettingRow("Assombrir") {
                        HStack(spacing: 8) {
                            Slider(value: $state.backgroundDim, in: 0...0.8)
                                .frame(width: 150)
                            Text("\(Int(state.backgroundDim * 100)) %")
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    SettingRow("Flou") {
                        HStack(spacing: 8) {
                            Slider(value: $state.backgroundBlur, in: 0...20)
                                .frame(width: 150)
                            Text("\(Int(state.backgroundBlur))")
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    Button("Réinitialiser les effets") {
                        state.backgroundDim = 0
                        state.backgroundBlur = 0
                    }
                    .glassButton()
                }

                Text("L'assombrissement et le flou s'appliquent immédiatement et sont conservés au prochain lancement.")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                GlassSection("À propos") {
                    HStack(spacing: 12) {
                        if let icon = NSApplication.shared.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 36, height: 36)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("trxqlf AutoClicker")
                                .foregroundColor(.primary)
                            Text("Version \(appVersion)")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.7))
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
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
                .foregroundColor(.primary)
            Spacer()
            Button(isRecording ? "Appuie sur une touche..." : combo.displayString) {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .frame(minWidth: 140)
            .glassButton()
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
