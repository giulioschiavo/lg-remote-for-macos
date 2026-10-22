import Cocoa
import SwiftUI

// Exports the real SwiftUI panel with synthetic data, without contacting a TV.
@MainActor
enum PreviewExport {
    static func run(to path: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let tv = TVRemote()
        tv.connected = true; tv.status = L("Collegata")
        tv.settings = CommandLine.arguments.contains("--preview-settings")
        tv.volume = 24; tv.volumeKnown = true; tv.channel = "1 · Live TV"
        tv.inputs = [TVInput(id: "HDMI_1", label: "HDMI 1", connected: true)]
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
