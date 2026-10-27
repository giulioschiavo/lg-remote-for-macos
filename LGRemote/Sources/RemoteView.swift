import Cocoa
import SwiftUI

@MainActor
final class RemotePanelState: ObservableObject {
    @Published var manualAddress = CommandLine.arguments.contains("--preview-manual-address")
    @Published var broadcastDetails = false
    @Published var otherTV = false
    @Published var confirmForget = false
    @Published var confirmPair = false
    @Published var navigationMode = 0
    @Published var changingVolume = false
    @Published var draftVolume = 0.0
}

@MainActor
struct RemoteView: View {
    @ObservedObject var tv: TVRemote
    @ObservedObject private var updates = UpdateChecker.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @StateObject private var ui = RemotePanelState()
    @AppStorage("settingsPane") private var settingsPane = 0
    @AppStorage("magicRemoteEnabled") private var magicRemoteEnabled = true
    @AppStorage("pointerSensitivity") private var pointerSensitivity = 4.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let release = updates.available {
                HStack {
                    Label(LF("Disponibile la versione %@", release.tag_name), systemImage: "arrow.down.circle")
                    Spacer()
                    Button(L("Apri Release")) { updates.openRelease() }
                }.font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            }
            if tv.settings { settings } else { controls }
            if let error = tv.error {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { tv.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help(L("Chiudi avviso"))
                }.font(.system(size: 11)).foregroundStyle(.red)
            }
            Divider()
            HStack {
                Spacer()
                Button(L("Esci")) { NSApp.terminate(nil) }.buttonStyle(.borderless).keyboardShortcut("q")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(18).frame(width: 360).fixedSize(horizontal: false, vertical: true)
        .background {
            if reduceTransparency { RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .windowBackgroundColor)) }
            else { RoundedRectangle(cornerRadius: 12).fill(.regularMaterial) }
        }
    }
    private var header: some View {
        HStack(spacing: 11) {
            Image(nsImage: RemoteIcon.menuBar()).resizable().scaledToFit().frame(width: 26, height: 31)
            VStack(alignment: .leading, spacing: 4) {
                Text("LG TV").font(.system(size: 20, weight: .semibold))
                HStack(spacing: 5) {
                    Circle().fill(tv.connected ? Color.green : Color.secondary).frame(width: 6, height: 6)
                    Text(tv.status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            circleButton(tv.settings ? "xmark" : "gearshape", tv.settings ? L("Chiudi impostazioni") : L("Impostazioni")) { tv.settings.toggle() }
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button { tv.wake() } label: { Label(L("Accendi"), systemImage: "power").frame(maxWidth: .infinity) }
                    .disabled(tv.connected || tv.connecting)
                Button { tv.powerOff() } label: { Label(L("Spegni"), systemImage: "power").frame(maxWidth: .infinity) }
                    .disabled(!tv.connected)
            }.controlSize(.large)
            if !tv.connected { connection }
            VStack(alignment: .leading, spacing: 14) {
                volume
                channels
                HStack {
                    Label(L("Sorgente"), systemImage: "rectangle.connected.to.line.below").fontWeight(.medium)
                    Spacer()
                    Menu {
                        Button(L("TV · Digitale terrestre")) { tv.command("system.launcher/launch", ["id": "com.webos.app.livetv"]) }
                        Divider()
                        ForEach(tv.inputs) { input in
                            Button(input.label + (input.connected ? L(" · collegata") : "")) { tv.command("tv/switchInput", ["inputId": input.id]) }
                        }
                        Divider()
                        Button(L("Aggiorna sorgenti")) { Task { await tv.refresh() } }
                    } label: { Text(L("Seleziona…")) }.frame(width: 155, alignment: .trailing)
                }
                Divider()
                navigation
            }.disabled(!tv.connected)
        }.font(.system(size: 13))
    }
    private var connection: some View {
        HStack(spacing: 10) {
            if tv.connecting { ProgressView().controlSize(.small) }
            Text(tv.connecting ? L("Attendi il collegamento. Se richiesto, conferma sulla TV.") : L("TV e Mac devono essere sulla stessa rete."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 3)
    }
    private var volume: some View {
        VStack(spacing: 9) {
            HStack {
                Text(L("Volume")).fontWeight(.medium)
                Spacer()
                Text(tv.volumeKnown ? "\(Int((ui.changingVolume ? ui.draftVolume : tv.volume).rounded()))" : "—")
                    .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                Button { tv.command("audio/setMute", ["mute": !tv.muted]) } label: {
                    Image(systemName: tv.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 24, height: 24)
                }.buttonStyle(.borderless).foregroundStyle(.primary)
                    .help(tv.muted ? L("Riattiva audio") : L("Disattiva audio"))
                    .accessibilityLabel(tv.muted ? L("Riattiva audio") : L("Disattiva audio"))
                    .accessibilityValue(tv.muted ? L("Audio disattivato") : L("Audio attivo"))
            }
            HStack(spacing: 10) {
                miniButton("minus", L("Abbassa volume")) { tv.command("audio/volumeDown") }
                Slider(value: Binding(get: { ui.changingVolume ? ui.draftVolume : tv.volume }, set: { ui.draftVolume = $0 }), in: 0...100, onEditingChanged: { editing in
                    if editing { ui.changingVolume = true }
                    else {
                        ui.changingVolume = false; tv.volume = ui.draftVolume.rounded()
                        tv.command("audio/setVolume", ["volume": Int(ui.draftVolume.rounded())])
                    }
                }).tint(.accentColor).accessibilityLabel(L("Volume della TV")).disabled(!tv.volumeKnown)
                  .onAppear { ui.draftVolume = tv.volume }
                  .onChange(of: tv.volume) { value in if !ui.changingVolume { ui.draftVolume = value } }
                miniButton("plus", L("Alza volume")) { tv.command("audio/volumeUp") }
            }
        }.padding(12).background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }
    private var channels: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(L("Canali")).fontWeight(.medium)
                Spacer(minLength: 6)
                miniButton("chevron.down", L("Canale precedente")) { tv.changeChannel(false) }
                miniButton("chevron.up", L("Canale successivo")) { tv.changeChannel(true) }
                TextField(L("N°"), text: $tv.enteringChannel).accessibilityLabel(L("Numero canale")).textFieldStyle(.roundedBorder).frame(width: 58).onSubmit { tv.goToChannel() }
                Button(L("Vai")) { tv.goToChannel() }
            }
            if !tv.channel.isEmpty { Text(tv.channel).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
        }
    }
    private var navigation: some View {
        VStack(spacing: 10) {
            if magicRemoteEnabled {
            Picker(L("Navigazione"), selection: $ui.navigationMode) {
                Text(L("Touchpad")).tag(0); Text(L("Tasti")).tag(1)
            }.pickerStyle(.segmented).labelsHidden()
            }
            if magicRemoteEnabled && ui.navigationMode == 0 {
                MagicTouchpad(enabled: tv.connected, sensitivity: pointerSensitivity,
                              onMove: { tv.enqueueInput(.move($0, $1)) }, onClick: { tv.enqueueInput(.click) },
                              onScroll: { tv.enqueueInput(.scroll($0, $1)) }, onBack: { tv.press("BACK") }, onStop: { tv.stopPointerMotion() })
                    .frame(height: 138)
                Text(L("Muovi il mouse qui. Clic per selezionare, due dita per scorrere."))
                    .font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                VStack(spacing: 6) {
                    nav("chevron.up", L("Su"), "UP")
                    HStack(spacing: 8) {
                        nav("chevron.left", L("Sinistra"), "LEFT")
                        Button("OK") { tv.press("ENTER") }.fontWeight(.semibold).frame(width: 54, height: 32).buttonStyle(.borderedProminent)
                        nav("chevron.right", L("Destra"), "RIGHT")
                    }
                    nav("chevron.down", L("Giù"), "DOWN")
                }.frame(height: 160)
            }
            HStack(spacing: 10) {
                Button { tv.press("BACK") } label: { Label(L("Indietro"), systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity) }
                Button { tv.press("HOME") } label: { Label(L("Home"), systemImage: "house").frame(maxWidth: .infinity) }
            }.controlSize(.large)
        }
    }
    private func circleButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 30, height: 30).background(Color.primary.opacity(0.06), in: Circle()) }
            .buttonStyle(.plain).help(label).accessibilityLabel(label).keyboardShortcut(",")
    }
    private func miniButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 24, height: 24) }
            .help(label).accessibilityLabel(label)
    }
    private func nav(_ symbol: String, _ label: String, _ key: String) -> some View {
        Button { tv.press(key) } label: { Image(systemName: symbol).frame(width: 38, height: 28) }.help(label).accessibilityLabel(label)
    }
    private var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    private var settings: some View {
        VStack(spacing: 12) {
            Picker(L("Sezione impostazioni"), selection: $settingsPane) {
                Text(L("TV")).tag(0)
                Text(L("Accensione")).tag(1)
                Text(L("App")).tag(2)
            }.pickerStyle(.segmented).labelsHidden()
            Group {
                if settingsPane == 1 { wakeSettings }
                else if settingsPane == 2 { appSettings }
                else { connectionSettings }
            }.frame(height: 350)
            HStack {
                Text(L("Telecomando LG"))
                Spacer()
                Text(LF("Versione %@", appVersion))
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }.font(.system(size: 12))
    }
    private var savedTVSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "tv").font(.system(size: 22)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("TV associata")).font(.headline)
                    Text(tv.host).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    Text(tv.connected ? L("Collegamento attivo") : L("Associazione salvata"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if !tv.connected {
                Text(L("Per accendere la TV usa Accendi nel telecomando. Ricollega serve quando la TV è già accesa."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(tv.connecting ? L("Annulla") : L("Ricollega")) {
                    let cancel = tv.connecting
                    tv.disconnect(); if !cancel { tv.connect() }
                }.buttonStyle(.borderedProminent)
            }
            Divider()
            Text(L("Gestisci associazione")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(L("Ripeti associazione")) { ui.confirmPair = true }
                    .disabled(!tv.connected)
                    .alert(L("Ripeti associazione"), isPresented: $ui.confirmPair) {
                        Button(L("Annulla"), role: .cancel) { }
                        Button(L("Continua")) { tv.rePair() }
                    } message: { Text(L("Conferma la richiesta sulla TV. Se il tentativo fallisce, il collegamento precedente resta salvato.")) }
                Button(L("Rimuovi associazione"), role: .destructive) { ui.confirmForget = true }
                    .alert(L("Rimuovere l’associazione alla TV?"), isPresented: $ui.confirmForget) {
                        Button(L("Annulla"), role: .cancel) { }
                        Button(L("Rimuovi associazione"), role: .destructive) { tv.forgetTV() }
                    } message: { Text(L("Verranno rimossi l’associazione dal Portachiavi, l’indirizzo della TV, il MAC e il broadcast salvati. Per collegarti di nuovo dovrai confermare sulla TV.")) }
            }.buttonStyle(.bordered).controlSize(.small)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
    private var connectionSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !tv.host.isEmpty {
                    savedTVSettings
                    Button {
                        ui.otherTV.toggle()
                    } label: {
                        HStack {
                            Text(L("Configura un’altra TV")).fontWeight(.medium)
                            Spacer()
                            Image(systemName: ui.otherTV ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .semibold))
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityValue(ui.otherTV ? L("Espanso") : L("Compresso"))
                }
                if tv.host.isEmpty || ui.otherTV {
                    discoverySettings
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8).padding(.horizontal, 2)
        }.scrollIndicators(.visible)
    }
    private var discoverySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Cerca una TV")).font(.headline)
            Text(L("Accendi la TV e collegala alla stessa rete del Mac."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(tv.discoveringTVs ? L("Ricerca in corso…") : L("Cerca TV")) { tv.searchTVs() }
                    .buttonStyle(.borderedProminent).disabled(tv.discoveringTVs || tv.preparingTV)
                if tv.discoveringTVs {
                    ProgressView().controlSize(.small)
                    Button(L("Annulla")) { tv.cancelDiscovery(); tv.discoveryMessage = L("Ricerca annullata") }
                }
            }
            if !tv.discoveryMessage.isEmpty {
                Text(tv.discoveryMessage).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(tv.discoveredTVs) { found in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(found.name).fontWeight(.medium).lineLimit(2)
                        Text(found.host).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L("Collega")) { tv.selectTV(found) }.disabled(tv.preparingTV)
                }
            }
            Button {
                ui.manualAddress.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: ui.manualAddress ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(L("Inserisci indirizzo manualmente"))
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(tv.preparingTV)
                .accessibilityValue(ui.manualAddress ? L("Espanso") : L("Compresso"))
            if ui.manualAddress {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(L("Indirizzo TV"), text: $tv.host).textFieldStyle(.roundedBorder)
                    Text(L("Nome locale o IPv4, senza http://")).font(.system(size: 11)).foregroundStyle(.secondary)
                    Button(L("Salva e collega")) { tv.saveSettings() }.disabled(tv.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(.top, 6).disabled(tv.preparingTV)
            }
        }.padding(.horizontal, 12)
    }
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
    private var wakeSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                settingsCard {
                    Label(L("Accensione dalla rete"), systemImage: "power").font(.headline)
                    Text(L("Accendi la TV sulla stessa rete del Mac tramite Wake-on-LAN."))
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(L("MAC della TV")).font(.system(size: 11, weight: .semibold))
                    TextField("AA:BB:CC:DD:EE:FF", text: $tv.mac).textFieldStyle(.roundedBorder)
                        .accessibilityLabel(L("MAC della TV"))
                    Button(tv.detectingMAC ? L("Ricerca MAC della TV…") : L("Rileva MAC dalla TV")) { tv.detectMAC() }
                        .disabled(tv.detectingMAC || !tv.connected)
                    Text(L("Rilevalo con la TV collegata. Usa il MAC Wi-Fi o Ethernet della connessione attiva."))
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !tv.macDetectionMessage.isEmpty {
                Text(tv.macDetectionMessage).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(tv.macCandidates) { candidate in
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.address).monospaced()
                    Text(L(candidate.source == "wifi" ? "Wi-Fi · rilevato dalla TV" : candidate.source == "wired" ? "Ethernet · rilevato dalla TV" : candidate.source == "wifi-unverified" ? "Wi-Fi · verifica la connessione attiva" : candidate.source == "wired-unverified" ? "Ethernet · verifica la connessione attiva" : "Cache di rete · da verificare sulla TV")).font(.system(size: 11)).foregroundStyle(.secondary)
                    Button(L("Usa questo MAC")) { tv.applyMAC(candidate) }
                }
            }
                }
                Button { ui.broadcastDetails.toggle() } label: {
                    HStack {
                        Text(L("Impostazioni di rete")).fontWeight(.medium)
                        Spacer()
                        Image(systemName: ui.broadcastDetails ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .semibold))
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityValue(ui.broadcastDetails ? L("Espanso") : L("Compresso"))
                if ui.broadcastDetails {
                    settingsCard {
                        Text(L("Indirizzo broadcast")).font(.system(size: 11, weight: .semibold))
                        TextField("192.168.1.255", text: $tv.broadcast).textFieldStyle(.roundedBorder)
                            .accessibilityLabel(L("Indirizzo broadcast"))
                        Text(L("Calcolato dalla rete quando possibile. Modificalo solo se conosci la sottorete della TV."))
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(L("Sulla TV abilita l’accensione tramite Wi-Fi nelle impostazioni per dispositivi mobili."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(L("Salva e collega")) { tv.saveSettings() }.buttonStyle(.borderedProminent)
            }.padding(.vertical, 8).padding(.horizontal, 2)
        }.scrollIndicators(.visible)
    }
    private var appSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                settingsCard {
                    Label(L("Controlli"), systemImage: "cursorarrow.motionlines").font(.headline)
                    Toggle(L("Puntatore Magic Remote"), isOn: $magicRemoteEnabled)
                        .onChange(of: magicRemoteEnabled) { enabled in tv.stopPointerMotion(); ui.navigationMode = enabled ? 0 : 1 }
                    if magicRemoteEnabled {
                        Text(L("Velocità puntatore")).font(.system(size: 11)).foregroundStyle(.secondary)
                        Picker(L("Velocità puntatore"), selection: $pointerSensitivity) {
                            Text("1×").tag(2.0)
                            Text("2×").tag(4.0)
                            Text("3×").tag(6.0)
                            Text("4×").tag(8.0)
                        }.pickerStyle(.segmented).labelsHidden()
                    }
                }
                settingsCard {
                    Label(L("Aggiornamenti"), systemImage: "arrow.down.circle").font(.headline)
                    Toggle(L("Controlla automaticamente"), isOn: Binding(get: { updates.automatic }, set: { updates.setAutomatic($0) }))
                    Text(L("Contatta GitHub all’avvio e ogni 24 ore mentre l’app è aperta. Nessuna installazione automatica."))
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(L("Controlla ora")) { updates.check(manual: true) }.disabled(updates.checking)
                        if updates.checking { ProgressView().controlSize(.small) }
                    }
                    if !updates.message.isEmpty {
                        Text(updates.message).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.padding(.vertical, 8).padding(.horizontal, 2)
        }.scrollIndicators(.visible)
    }
}
