import Cocoa
import SwiftUI

@MainActor
final class RemotePanelState: ObservableObject {
    @Published var navigationMode = 0
    @Published var changingVolume = false
    @Published var draftVolume = 0.0
}

@MainActor
struct RemoteView: View {
    @ObservedObject var tv: TVRemote
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @StateObject private var ui = RemotePanelState()
    @AppStorage("magicRemoteEnabled") private var magicRemoteEnabled = true
    @AppStorage("pointerSensitivity") private var pointerSensitivity = 4.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
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
                Button {
                    let cancel = tv.connecting
                    tv.disconnect(); if !cancel { tv.connect() }
                } label: { Label(tv.connecting ? L("Annulla") : L("Ricollega"), systemImage: tv.connecting ? "xmark" : "arrow.clockwise") }
                .buttonStyle(.borderless)
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
                    } label: { Text(L("Seleziona…")) }.frame(width: 155)
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
            if !tv.connecting { Button(L("Collega")) { tv.connect() }.buttonStyle(.borderedProminent) }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Collegamento")).font(.headline)
            TextField(L("Indirizzo TV"), text: $tv.host).textFieldStyle(.roundedBorder)
            Text(L("Nome locale o IPv4, senza http://")).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(L("Accensione dalla rete")).font(.headline).padding(.top, 4)
            TextField(L("MAC della TV · AA:BB:CC:DD:EE:FF"), text: $tv.mac).textFieldStyle(.roundedBorder)
            TextField(L("Broadcast · 192.168.1.255"), text: $tv.broadcast).textFieldStyle(.roundedBorder)
            Text(L("Attiva l’accensione da dispositivo mobile sulla TV. Usa il MAC della connessione Wi-Fi o Ethernet, non l’identificativo AirPlay."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(L("Salva e collega")) { tv.saveSettings() }.buttonStyle(.borderedProminent)
            Button(L("Nuova associazione")) { tv.rePair() }.buttonStyle(.borderless)
            Divider().padding(.vertical, 2)
            Toggle(L("Puntatore Magic Remote"), isOn: $magicRemoteEnabled)
                .onChange(of: magicRemoteEnabled) { enabled in tv.stopPointerMotion(); ui.navigationMode = enabled ? 0 : 1 }
            if magicRemoteEnabled {
            Text(L("Velocità puntatore")).font(.headline)
            Picker(L("Velocità puntatore"), selection: $pointerSensitivity) {
                Text("1×").tag(2.0)
                Text("2×").tag(4.0)
                Text("3×").tag(6.0)
                Text("4×").tag(8.0)
            }.pickerStyle(.segmented).labelsHidden()
            }
            Divider().padding(.top, 2)
            HStack {
                Text(L("Telecomando LG"))
                Spacer()
                Text(LF("Versione %@", appVersion))
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }.font(.system(size: 12))
    }
}
