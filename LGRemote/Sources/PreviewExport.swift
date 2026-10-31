import Cocoa
import SwiftUI

// Exports the real SwiftUI panel with synthetic data, without contacting a TV.
@MainActor
enum PreviewExport {
    static func run(to path: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let tv = TVRemote()
        tv.displayName = "LG webOS TV"
        tv.host = "LGwebOSTV.local"; tv.mac = "02:00:00:00:00:01"; tv.broadcast = "192.168.1.255"
        tv.connected = true; tv.status = L("Collegata")
        tv.settings = CommandLine.arguments.contains("--preview-settings")
        tv.volume = 24; tv.volumeKnown = true; tv.channel = "1 · Live TV"
        tv.inputs = [TVInput(id: "HDMI_1", label: "HDMI 1", connected: true)]
        if CommandLine.arguments.contains("--preview-discovery-empty") || CommandLine.arguments.contains("--preview-discovery-found") {
            tv.connected = false; tv.host = ""; tv.mac = ""; tv.status = L("Pronto per collegarsi"); tv.settings = true
        }
        if CommandLine.arguments.contains("--preview-discovery-found") {
            tv.discoveredTVs = [DiscoveredTV(host: "192.0.2.10", name: "LG webOS TV")]
            tv.discoveryMessage = L("Scegli la TV e conferma la richiesta sul televisore.")
        }
        let host = NSHostingController(rootView: RemoteView(tv: tv))
        let size = host.sizeThatFits(in: NSSize(width: 360, height: 2000))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = host
        window.isOpaque = false; window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .aqua)
        host.view.frame = NSRect(origin: .zero, size: size)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            host.view.layoutSubtreeIfNeeded()
            guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) else { exit(1) }
            host.view.cacheDisplay(in: host.view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
            do { try data.write(to: URL(fileURLWithPath: path)); print("Preview exported: \(path)"); exit(0) }
            catch { fputs("Preview export failed\n", stderr); exit(1) }
        }
        app.run()
        withExtendedLifetime(window) {}
    }
}
