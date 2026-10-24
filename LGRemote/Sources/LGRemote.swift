import Cocoa
import SwiftUI
import Security
import Darwin

enum RemoteIcon {
    // A template is recolored by macOS for light/dark menu bars and selection states.
    static func menuBar() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 20), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let body = NSBezierPath(roundedRect: NSRect(x: 4.5, y: 1, width: 9, height: 18), xRadius: 3.2, yRadius: 3.2)
            body.lineWidth = 1.25; body.stroke()
            NSBezierPath(ovalIn: NSRect(x: 8, y: 15.5, width: 2, height: 2)).fill()
            let ring = NSBezierPath(ovalIn: NSRect(x: 6.5, y: 8.5, width: 5, height: 5))
            ring.lineWidth = 1.1; ring.stroke()
            NSBezierPath(ovalIn: NSRect(x: 8.35, y: 10.35, width: 1.3, height: 1.3)).fill()
            let buttons = NSBezierPath()
            buttons.move(to: NSPoint(x: 7, y: 5.8)); buttons.line(to: NSPoint(x: 11, y: 5.8))
            buttons.move(to: NSPoint(x: 7, y: 3.5)); buttons.line(to: NSPoint(x: 11, y: 3.5))
            buttons.lineWidth = 1; buttons.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = L("Telecomando LG")
        return image
    }
}

struct TVInput: Identifiable {
    let id: String
    let label: String
    let connected: Bool
}

enum RemoteError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

enum PairingStore {
    static func query(_ host: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "it.giulio.LGRemote.pairing",
         kSecAttrAccount as String: host]
    }
    static func read(_ host: String) throws -> String? {
        var q = query(host)
        q[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else {
            throw RemoteError.message(L("Impossibile leggere l’associazione dal Portachiavi. Consenti l’accesso a Telecomando LG e riprova; non serve associare di nuovo la TV."))
        }
        return key
    }
    static func save(_ key: String, host: String) -> Bool {
        let q = query(host)
        let attrs = [kSecValueData as String: Data(key.utf8)]
        if SecItemUpdate(q as CFDictionary, attrs as CFDictionary) == errSecSuccess { return true }
        return SecItemAdd(q.merging(attrs) { _, b in b } as CFDictionary, nil) == errSecSuccess
    }
    static func remove(_ host: String) -> Bool {
        let result = SecItemDelete(query(host) as CFDictionary)
        return result == errSecSuccess || result == errSecItemNotFound
    }
}

enum WakeOnLAN {
    static func bytes(_ mac: String) -> [UInt8]? {
        let parts = mac.replacingOccurrences(of: "-", with: ":").split(separator: ":")
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }),
              parts.allSatisfy({ UInt8($0, radix: 16) != nil }) else { return nil }
        let result = parts.compactMap { UInt8($0, radix: 16) }
        guard result != [0,0,0,0,0,0], result[0] & 1 == 0 else { return nil }
        return result
    }
    static func packet(_ mac: String) throws -> Data {
        guard let address = bytes(mac) else { throw RemoteError.message(L("Inserisci il MAC della scheda di rete della TV nelle impostazioni.")) }
        return Data(Array(repeating: UInt8(255), count: 6) + Array(repeating: address, count: 16).flatMap { $0 })
    }
    static func send(mac: String, broadcast: String) throws {
        let data = try packet(mac)
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw RemoteError.message(L("Impossibile aprire la connessione di rete.")) }
        defer { close(fd) }
        var enabled: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enabled, socklen_t(MemoryLayout.size(ofValue: enabled))) == 0 else {
            throw RemoteError.message(L("Invio broadcast non consentito."))
        }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(9).bigEndian
        guard inet_pton(AF_INET, broadcast, &address.sin_addr) == 1 else {
            throw RemoteError.message(L("L’indirizzo broadcast deve essere un indirizzo IPv4."))
        }
        let sent = data.withUnsafeBytes { buffer in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == data.count else { throw RemoteError.message(L("Invio Wake-on-LAN non riuscito: controlla la rete locale.")) }
    }
}

@MainActor
final class TVRemote: NSObject, ObservableObject {
    @Published var host = UserDefaults.standard.string(forKey: "host") ?? ""
    @Published var mac = UserDefaults.standard.string(forKey: "mac") ?? ""
    @Published var broadcast = UserDefaults.standard.string(forKey: "broadcast") ?? "192.168.1.255"
    @Published var connected = false
    @Published var connecting = false
    @Published var status = L("Pronto per collegarsi")
    @Published var error: String?
    @Published var volume: Double = 0
    @Published var volumeKnown = false
    @Published var muted = false
    @Published var inputs: [TVInput] = []
    @Published var channel = ""
    @Published var settings = false
    @Published var enteringChannel = ""
    @Published var detectingMAC = false
    @Published var macCandidates: [MACCandidate] = []
    @Published var macDetectionMessage = ""
    @Published var discoveringTVs = false
    @Published var discoveredTVs: [DiscoveredTV] = []
    @Published var discoveryMessage = ""
    @Published var preparingTV = false
    private var discoveryTask: Task<Void, Never>?
    private var discoveryGeneration = UUID()
    private var activeHost: String?
    private var identityTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var wakeGeneration = UUID()
    private var session = URLSession(configuration: .default)
    private var socket: URLSessionWebSocketTask?
    private var buttonSocket: URLSessionWebSocketTask?
    private var reader: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var poller: Task<Void, Never>?
    private var generation = UUID()
    private var count = 0
    private var powerOffPending = false
    private var usingSavedKey = false
    private var activePairingKey: String?
    private var activePairingAccount: String?
    private var inputEvents: [RemoteInputEvent] = []
    private var inputWorker: Task<Void, Never>?
    private static let permissionRevision = 2
    private var pending: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var requestTimers: [String: Task<Void, Never>] = [:]

    func saveSettings(allowRediscovery: Bool = true) {
        let priorHost = UserDefaults.standard.string(forKey: "host") ?? ""
        if !priorHost.isEmpty && priorHost != host.trimmingCharacters(in: .whitespacesAndNewlines) {
            UserDefaults.standard.removeObject(forKey: "tvDeviceID")
            UserDefaults.standard.removeObject(forKey: "pairingLegacyHost")
        }
        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        mac = mac.trimmingCharacters(in: .whitespacesAndNewlines)
        broadcast = broadcast.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(host, forKey: "host")
        UserDefaults.standard.set(mac, forKey: "mac")
        UserDefaults.standard.set(broadcast, forKey: "broadcast")
        settings = false
        disconnect()
        connect(allowRediscovery: allowRediscovery)
    }
    func disconnect() {
        cancelDiscovery()
        generation = UUID()
        activeHost = nil
        identityTask?.cancel(); identityTask = nil; detectingMAC = false
        macCandidates = []; macDetectionMessage = ""
        wakeGeneration = UUID(); wakeTask?.cancel(); wakeTask = nil
        reader?.cancel(); deadline?.cancel(); poller?.cancel(); inputWorker?.cancel()
        inputWorker = nil; inputEvents.removeAll()
        socket?.cancel(with: .goingAway, reason: nil)
        buttonSocket?.cancel(with: .goingAway, reason: nil)
        socket = nil; buttonSocket = nil
        connected = false; connecting = false; volumeKnown = false
        powerOffPending = false
        inputs = []; channel = ""
        status = L("Non collegato")
        failPending()
    }
    private func failPending() {
        let callbacks = pending; pending.removeAll()
        requestTimers.values.forEach { $0.cancel() }; requestTimers.removeAll()
        for callback in callbacks.values { callback.resume(throwing: RemoteError.message(L("Collegamento interrotto."))) }
    }
    func connect(forcePairing: Bool = false, allowRediscovery: Bool = true) {
        guard !connected && !connecting else { return }
        cancelDiscovery()
        let savedIdentity = UserDefaults.standard.string(forKey: "host") == host ? UserDefaults.standard.string(forKey: "tvDeviceID") : nil
        let account = savedIdentity.map { "device:" + $0 } ?? host
        // The plain WebSocket transport was verified on this specific LG by the user.
        guard !host.isEmpty, !host.contains("/"), !host.contains(":"), !host.contains(" "),
              let url = URL(string: "ws://\(host):3000") else {
            error = L("Inserisci un nome di rete o un indirizzo IPv4 valido, senza http://."); return
        }
        let savedKey: String?
        do {
            if forcePairing { savedKey = nil }
            else if let stable = try PairingStore.read(account) { savedKey = stable }
            else if let legacy = UserDefaults.standard.string(forKey: "pairingLegacyHost"), savedIdentity != nil {
                savedKey = try PairingStore.read(legacy)
            } else { savedKey = try PairingStore.read(host) }
        }
        catch { self.error = error.localizedDescription; return }
        usingSavedKey = savedKey != nil
        activePairingKey = savedKey
        activePairingAccount = account
        let updatePermissions = savedKey != nil && UserDefaults.standard.integer(forKey: "permissionRevision.\(host)") < Self.permissionRevision
        error = nil; connecting = true; status = L("Connessione a LG 55…")
        let connectionHost = host
        generation = UUID(); let token = generation
        let ws = session.webSocketTask(with: url)
        socket = ws; ws.resume()
        reader = Task {
            do {
                var payload: [String: Any] = [
                    "pairingType": "PROMPT",
                    "forcePairing": forcePairing || updatePermissions,
                    "manifest": ["manifestVersion": 1, "appVersion": "1.0",
                        "permissions": ["CONTROL_AUDIO", "CONTROL_POWER", "CONTROL_INPUT_TV",
                            "CONTROL_INPUT_JOYSTICK", "CONTROL_INPUT_MEDIA_PLAYBACK", "LAUNCH",
                            "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD",
                            "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST", "READ_NETWORK_STATE"]]
                ]
                if let key = savedKey { payload["client-key"] = key }
                try await send(["id": "pair", "type": "register", "payload": payload], over: ws)
                guard token == generation else { return }
                status = savedKey == nil || updatePermissions ? L("Accetta il collegamento sulla TV") : L("Ripristino associazione salvata…")
                while !Task.isCancelled {
                    let message = try await ws.receive()
                    guard token == generation else { return }
                    let data: Data
                    switch message { case .string(let text): data = Data(text.utf8); case .data(let bytes): data = bytes; @unknown default: continue }
                    guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    handle(body, connectionHost: connectionHost)
                }
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                let shuttingDown = powerOffPending
                let wasConnected = connected
                disconnect()
                if shuttingDown {
                    status = L("TV disconnessa dopo richiesta spegnimento")
                    self.error = nil
                } else if !wasConnected, allowRediscovery, !forcePairing, let savedIdentity {
                    rediscoverSavedTV(identity: savedIdentity)
                } else {
                    self.error = L("TV non raggiungibile. Controlla che sia accesa e sulla stessa rete, poi premi Collega.")
                }
            }
        }
        deadline = Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard !Task.isCancelled, token == generation, !connected else { return }
            disconnect(); error = L("Autorizzazione non completata. Premi Collega e accetta sulla TV.")
        }
    }
    private func handle(_ body: [String: Any], connectionHost: String) {
        let type = body["type"] as? String ?? ""
        let payload = body["payload"] as? [String: Any] ?? [:]
        let id = body["id"] as? String ?? ""
        if type == "registered" {
            deadline?.cancel(); connecting = false; connected = true; activeHost = connectionHost; status = L("Collegata")
            if let key = payload["client-key"] as? String ?? activePairingKey, !PairingStore.save(key, host: activePairingAccount ?? connectionHost) {
                error = L("Collegata, ma non è stato possibile salvare l’associazione nel Portachiavi.")
            } else if payload["client-key"] is String || usingSavedKey {
                UserDefaults.standard.set(connectionHost, forKey: "pairedHost")
                UserDefaults.standard.set(Self.permissionRevision, forKey: "permissionRevision.\(connectionHost)")
            }
            Task { await refresh() }
            if mac.isEmpty { detectMAC(automatic: true) }
            poller = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    guard !Task.isCancelled, connected else { return }
                    await refreshVolume()
                }
            }
        } else if id == "pair", payload["pairingType"] as? String == "PROMPT" {
            status = L("Accetta il collegamento sulla TV")
        } else if let callback = pending.removeValue(forKey: id) {
            requestTimers.removeValue(forKey: id)?.cancel()
            if type == "error" || payload["returnValue"] as? Bool == false {
                callback.resume(throwing: RemoteError.message(body["error"] as? String ?? payload["errorText"] as? String ?? L("Comando non disponibile sulla TV.")))
            } else { callback.resume(returning: payload) }
        } else if type == "error" && id == "pair" {
            disconnect()
            error = L("Associazione rifiutata. Premi Nuova associazione nelle impostazioni e accetta sulla TV.")
        }
    }
    private func send(_ object: [String: Any], over ws: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await ws.send(.string(String(decoding: data, as: UTF8.self)))
    }
    func request(_ uri: String, payload: [String: Any] = [:]) async throws -> [String: Any] {
        guard connected, let ws = socket else { throw RemoteError.message(L("Collega prima la TV.")) }
        count += 1; let id = "r\(count)"
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            requestTimers[id] = Task {
                do {
                    try await send(["id": id, "type": "request", "uri": "ssap://\(uri)", "payload": payload], over: ws)
                    try await Task.sleep(nanoseconds: 6_000_000_000)
                    if let callback = pending.removeValue(forKey: id) {
                        requestTimers.removeValue(forKey: id)
                        callback.resume(throwing: RemoteError.message(L("La TV non ha risposto al comando. Riprova.")))
                    }
                } catch {
                    if let callback = pending.removeValue(forKey: id) {
                        requestTimers.removeValue(forKey: id)
                        callback.resume(throwing: error)
                    }
                }
            }
        }
    }
    func command(_ uri: String, _ payload: [String: Any] = [:]) {
        Task {
            error = nil
            do { _ = try await request(uri, payload: payload); await refreshVolume() }
            catch { self.error = error.localizedDescription }
        }
    }
    func refreshVolume() async {
        guard let result = try? await request("audio/getVolume") else { return }
        let value = result["volumeStatus"] as? [String: Any] ?? result
        if let number = value["volume"] as? NSNumber { volume = min(100, max(0, number.doubleValue)); volumeKnown = true }
        if let state = value["muted"] as? Bool { muted = state }
        else if let state = value["muteStatus"] as? Bool { muted = state }
    }
    func refresh() async {
        await refreshVolume()
        if let result = try? await request("tv/getExternalInputList"), let devices = result["devices"] as? [[String: Any]] {
            inputs = devices.compactMap {
                guard let id = $0["id"] as? String else { return nil }
                return TVInput(id: id, label: $0["label"] as? String ?? id, connected: $0["connected"] as? Bool ?? false)
            }
        }
        await refreshChannel()
    }
    func refreshChannel() async {
        if let result = try? await request("tv/getCurrentChannel") {
            channel = [result["channelNumber"] as? String, result["channelName"] as? String].compactMap { $0 }.joined(separator: " · ")
        } else { channel = "" }
    }
    func changeChannel(_ up: Bool) {
        Task {
            do { _ = try await request(up ? "tv/channelUp" : "tv/channelDown"); await refreshChannel() }
            catch { self.error = error.localizedDescription }
        }
    }
    func goToChannel() {
        guard !enteringChannel.isEmpty, enteringChannel.count <= 5,
              enteringChannel.allSatisfy({ $0.isASCII && $0.isNumber }) else { error = L("Inserisci un numero di canale valido."); return }
        command("tv/openChannel", ["channelNumber": enteringChannel])
    }
    func press(_ name: String) {
        enqueueInput(.button(name))
    }
    private func inputSocket() async throws -> URLSessionWebSocketTask {
        guard connected else { throw RemoteError.message(L("Collega prima la TV.")) }
        if let buttonSocket { return buttonSocket }
        let token = generation
        let result = try await request("com.webos.service.networkinput/getPointerInputSocket")
        guard token == generation, connected else { throw RemoteError.message(L("Collegamento interrotto.")) }
        guard let path = result["socketPath"] as? String, let url = URL(string: path),
              ["ws", "wss"].contains(url.scheme ?? ""), url.host != nil else { throw RemoteError.message(L("Puntatore non disponibile.")) }
        let ws = session.webSocketTask(with: url); buttonSocket = ws; ws.resume()
        return ws
    }
    private var pointerMotionGeneration = 0
    func stopPointerMotion() {
        pointerMotionGeneration += 1
        inputEvents.removeAll { $0.isMotion }
    }
    func enqueueInput(_ event: RemoteInputEvent) {
        guard connected else { return }
        // Merge adjacent motion packets, but never move a click ahead of motion.
        if let last = inputEvents.last, let merged = last.merging(event) {
            inputEvents[inputEvents.count - 1] = merged
        } else if inputEvents.count < 128 { inputEvents.append(event) }
        guard inputWorker == nil else { return }
        let token = generation
        inputWorker = Task {
            do {
                while !Task.isCancelled && token == generation && !inputEvents.isEmpty {
                    let event = inputEvents.removeFirst()
                    let motionGeneration = pointerMotionGeneration
                    let ws = try await inputSocket()
                    guard !Task.isCancelled, token == generation else { return }
                    if event.isMotion && motionGeneration != pointerMotionGeneration { continue }
                    try await ws.send(.string(event.message))
                    if event.isMotion { try await Task.sleep(nanoseconds: 20_000_000) }
                }
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                buttonSocket?.cancel(); buttonSocket = nil; inputEvents.removeAll()
                if error.localizedDescription.contains("401") {
                    self.error = L("La TV non ha autorizzato puntatore e tasti. Apri Impostazioni → Nuova associazione e accetta sulla TV.")
                } else { self.error = LF("Puntatore non collegato. Riprova: %@", error.localizedDescription) }
            }
            if token == generation { inputWorker = nil }
        }
    }
    func powerOff() {
        Task {
            guard connected, !powerOffPending else { return }
            powerOffPending = true
            error = nil
            do {
                _ = try await request("system/turnOff")
                disconnect(); status = L("Spegnimento confermato"); error = nil
            } catch {
                powerOffPending = false
                if connected { self.error = error.localizedDescription }
            }
        }
    }
    func wake() {
        do {
            try WakeOnLAN.send(mac: mac, broadcast: broadcast)
            error = nil; status = L("Accensione richiesta…")
            wakeTask?.cancel(); let wakeToken = UUID(); wakeGeneration = wakeToken
            let target = host
            wakeTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, wakeToken == wakeGeneration, target == host, !connected, !connecting else { return }
                connect()
            }
        } catch { self.error = error.localizedDescription; settings = true }
    }
    func detectMAC(automatic: Bool = false) {
        guard connected, activeHost == host else {
            macDetectionMessage = L("Accendi la TV e collegala prima di rilevare il MAC. Il valore salvato resta disponibile per l’accensione.")
            return
        }
        guard !detectingMAC else { return }
        detectingMAC = true; macCandidates = []; macDetectionMessage = L("Ricerca MAC della TV…")
        let token = generation, target = host, initialMAC = mac
        identityTask = Task {
            defer { if token == generation { detectingMAC = false; identityTask = nil } }
            let result = try? await request("com.webos.service.connectionmanager/getinfo")
            guard !Task.isCancelled, token == generation, target == host, connected else { return }
            let networkStatus = try? await request("com.webos.service.connectionmanager/getStatus")
            guard !Task.isCancelled, token == generation, target == host, connected else { return }
            var candidates = result.map { TVNetworkIdentity.fromAPI($0, status: networkStatus) } ?? []
            if candidates.isEmpty, let fallback = await TVNetworkIdentity.fromARP(host: target) {
                candidates = [fallback]
            }
            guard !Task.isCancelled, token == generation, target == host, connected else { return }
            detectingMAC = false
            macCandidates = candidates
            if candidates.isEmpty {
                macDetectionMessage = L("MAC non rilevato. Controlla il MAC Wi-Fi o Ethernet nelle impostazioni della TV e inseriscilo manualmente.")
            } else if automatic && candidates.count == 1 && mac.isEmpty && initialMAC.isEmpty && ["wifi", "wired"].contains(candidates[0].source) {
                applyMAC(candidates[0])
            } else {
                macDetectionMessage = L("Verifica la scheda e premi Usa questo MAC. La ricerca non modifica il valore salvato.")
            }
            identityTask = nil
        }
    }
    func applyMAC(_ candidate: MACCandidate) {
        guard connected, activeHost == host, macCandidates.contains(candidate) else { return }
        mac = candidate.address
        UserDefaults.standard.set(mac, forKey: "mac")
        macDetectionMessage = L("MAC salvato per l’accensione. Verificalo con quello indicato dalla TV.")
        macCandidates = []
    }
    func searchTVs() {
        cancelDiscovery()
        let token = discoveryGeneration
        discoveringTVs = true; discoveredTVs = []
        discoveryMessage = L("Ricerca TV sulla rete locale…")
        discoveryTask = Task {
            do {
                let found = try await TVDiscovery.search()
                guard !Task.isCancelled, token == discoveryGeneration else { return }
                discoveredTVs = found
                discoveryMessage = found.isEmpty
                    ? L("Nessuna TV trovata. Accendila, verifica la stessa rete e consenti l’accesso alla rete locale per l’app nelle Impostazioni di Sistema. Poi riprova.")
                    : L("Scegli la TV e conferma la richiesta sul televisore.")
            } catch {
                guard !Task.isCancelled, token == discoveryGeneration else { return }
                discoveryMessage = L("Ricerca non riuscita. Verifica la rete e il permesso Rete locale dell’app, poi riprova.")
            }
            guard token == discoveryGeneration else { return }
            discoveringTVs = false; discoveryTask = nil
        }
    }
    func cancelDiscovery() {
        discoveryGeneration = UUID()
        discoveryTask?.cancel(); discoveryTask = nil
        discoveringTVs = false; preparingTV = false
    }
    func selectTV(_ selected: DiscoveredTV) {
        guard discoveredTVs.contains(selected), !preparingTV else { return }
        prepareTV(selected, allowRediscovery: true)
    }
    private func prepareTV(_ selected: DiscoveredTV, allowRediscovery: Bool) {
        disconnect()
        let token = discoveryGeneration
        preparingTV = true; discoveryMessage = L("Preparazione collegamento…")
        let previous = UserDefaults.standard.string(forKey: "host") ?? host
        let previousID = UserDefaults.standard.string(forKey: "tvDeviceID")
        let sameTV = previous == selected.host || (previousID != nil && previousID == selected.deviceID)
        discoveryTask = Task {
            let detectedBroadcast = await TVNetworkIdentity.broadcast(for: selected.host)
            guard !Task.isCancelled, token == discoveryGeneration else { return }
            if !sameTV { mac = ""; broadcast = "" }
            if let detectedBroadcast { broadcast = detectedBroadcast }
            else if previous != selected.host { broadcast = "" }
            if let identity = selected.deviceID {
                UserDefaults.standard.set(identity, forKey: "tvDeviceID")
                if sameTV && previousID == nil && !previous.isEmpty {
                    UserDefaults.standard.set(previous, forKey: "pairingLegacyHost")
                } else if !sameTV { UserDefaults.standard.removeObject(forKey: "pairingLegacyHost") }
            } else {
                UserDefaults.standard.removeObject(forKey: "tvDeviceID")
                UserDefaults.standard.removeObject(forKey: "pairingLegacyHost")
            }
            host = selected.host
            // Mark the host/identity change together so manual-address handling won't discard the identity.
            UserDefaults.standard.set(host, forKey: "host")
            discoveredTVs = []; discoveryMessage = ""
            preparingTV = false
            saveSettings(allowRediscovery: allowRediscovery)
        }
    }
    private func rediscoverSavedTV(identity: String) {
        cancelDiscovery()
        let token = discoveryGeneration
        discoveringTVs = true; status = L("Cerco la TV salvata…"); error = nil
        discoveryTask = Task {
            let results = (try? await TVDiscovery.search()) ?? []
            guard !Task.isCancelled, token == discoveryGeneration else { return }
            let matches = results.filter { $0.deviceID == identity }
            discoveringTVs = false
            if matches.count == 1 {
                prepareTV(matches[0], allowRediscovery: false)
            } else {
                status = L("TV non raggiungibile")
                error = L("TV salvata non trovata. Accendila e usa Cerca TV nelle impostazioni.")
                discoveryTask = nil
            }
        }
    }
    func rePair() {
        guard connected, activeHost == host else {
            error = L("Per una nuova associazione accendi la TV e premi Collega. L’associazione salvata non è stata rimossa.")
            return
        }
        disconnect(); settings = false; connect(forcePairing: true)
    }
    func forgetTV() {
        let savedHost = UserDefaults.standard.string(forKey: "host") ?? host
        var accounts = Set([savedHost])
        if let identity = UserDefaults.standard.string(forKey: "tvDeviceID") { accounts.insert("device:" + identity) }
        if let legacy = UserDefaults.standard.string(forKey: "pairingLegacyHost") { accounts.insert(legacy) }
        let removed = accounts.map { PairingStore.remove($0) }
        guard removed.allSatisfy({ $0 }) else {
            error = L("Impossibile rimuovere l’associazione dal Portachiavi. Consenti l’accesso all’app e riprova.")
            return
        }
        disconnect()
        for key in ["mac", "broadcast", "pairedHost", "tvDeviceID", "pairingLegacyHost", "permissionRevision.\(savedHost)"] { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.set("", forKey: "host")
        host = ""; mac = ""; broadcast = ""
        discoveredTVs = []; discoveryMessage = ""
        UserDefaults.standard.set(0, forKey: "settingsPane")
        error = nil; settings = true; status = L("Collegamento rimosso")
    }

}

@main
enum LGRemoteApplication {
@MainActor static func main() throws {
if let path = Bundle.main.object(forInfoDictionaryKey: "LGRemoteExportPath") as? String {
    PreviewExport.run(to: path)
} else if let index = CommandLine.arguments.firstIndex(of: "--export-preview"), CommandLine.arguments.count > index + 1 {
    PreviewExport.run(to: CommandLine.arguments[index + 1])
} else if CommandLine.arguments.contains("--discover-tvs") {
    Task {
        do { let found = try await TVDiscovery.search(); print("Discovery completed: \(found.count) webOS TV(s)"); exit(0) }
        catch { print("Discovery failed: \(error)"); exit(1) }
    }
    NSApplication.shared.run()
} else if CommandLine.arguments.contains("--self-test") {
    let offline = TVRemote()
    offline.host = "example.invalid"; offline.mac = "02:00:00:00:00:01"
    offline.rePair()
    precondition(offline.mac == "02:00:00:00:00:01" && offline.error != nil && !offline.connecting)
    offline.detectMAC()
    precondition(!offline.macDetectionMessage.isEmpty && !offline.detectingMAC && offline.macCandidates.isEmpty)
    let packet = try WakeOnLAN.packet("02:00:00:00:00:01")
    precondition(packet.count == 102)
    precondition(Array(packet.prefix(6)) == Array(repeating: 255, count: 6))
    precondition(Array(packet.suffix(6)) == [0x02,0,0,0,0,0x01])
    precondition(WakeOnLAN.bytes("01:00:00:00:00:01") == nil)
    precondition(WakeOnLAN.bytes("invalid") == nil)
    let fitted = MenuPanelPlacement.frame(size: NSSize(width: 360, height: 650), anchor: NSRect(x: 1400, y: 944, width: 24, height: 38), visible: NSRect(x: 0, y: 0, width: 1512, height: 944), screen: NSRect(x: 0, y: 0, width: 1512, height: 982), topInset: 38)
    precondition(fitted.maxY == 944 && fitted.maxX <= 1506)
    let external = MenuPanelPlacement.frame(size: NSSize(width: 360, height: 650), anchor: NSRect(x: -1920, y: 1055, width: 24, height: 25), visible: NSRect(x: -1920, y: 0, width: 1920, height: 1055), screen: NSRect(x: -1920, y: 0, width: 1920, height: 1080), topInset: 0)
    precondition(external.minX == -1914 && external.maxY == 1055)
    precondition(RemoteInputEvent.move(4, -3).message == "type:move\ndx:4\ndy:-3\ndown:0\n\n")
    precondition(RemoteInputEvent.click.message == "type:click\n\n")
    precondition(RemoteInputEvent.move(2, 3).merging(.click) == nil)
    precondition(RemoteInputEvent.move(2, 3).merging(.move(4, -1))?.message == "type:move\ndx:6\ndy:2\ndown:0\n\n")
    let expectedSettings = Bundle.main.preferredLocalizations.first == "it" ? "Impostazioni" : "Settings"
    precondition(L("Impostazioni") == expectedSettings)
    print("Locale: \(Bundle.main.preferredLocalizations.first ?? "unknown") — \(L("Telecomando LG"))")
    print("PASS: Wake-on-LAN, notch bounds, pointer protocol and click ordering")
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
}
}
