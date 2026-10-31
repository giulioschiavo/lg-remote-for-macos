import Cocoa
import SwiftUI

final class RemoteMenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum MenuPanelPlacement {
    static func frame(size: NSSize, anchor: NSRect, visible: NSRect, screen: NSRect, topInset: CGFloat) -> NSRect {
        let edge: CGFloat = 6
        // No gap above the panel: its top is exactly at the menu bar's bottom.
        let top = min(anchor.minY, visible.maxY, screen.maxY - topInset)
        let width = min(size.width, max(0, visible.width - edge * 2))
        let height = min(size.height, max(0, top - visible.minY - edge))
        let x = max(visible.minX + edge, min(anchor.midX - width / 2, visible.maxX - edge - width))
        return NSRect(x: x, y: top - height, width: width, height: height)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    let tv = TVRemote()
    private var panel: RemoteMenuPanel!
    private var host: NSHostingController<RemoteView>!
    private var sizeObserver: NSKeyValueObservation?
    private var localClickMonitor: Any?
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preview = CommandLine.arguments.contains("--preview") || Bundle.main.object(forInfoDictionaryKey: "LGRemotePreview") as? Bool == true
        NSApp.setActivationPolicy(preview ? .regular : .accessory)
        if preview {
            tv.status = L("Anteprima · dati dimostrativi")
            tv.volume = 14; tv.volumeKnown = true; tv.connected = true; tv.muted = true
        }
        if !preview && tv.host.isEmpty { tv.settings = true; UserDefaults.standard.set(0, forKey: "settingsPane") }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = RemoteIcon.menuBar()
            button.target = self; button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseDown])
            button.toolTip = L("Telecomando LG")
        }
        host = NSHostingController(rootView: RemoteView(tv: tv))
        host.sizingOptions = [.preferredContentSize]
        panel = RemoteMenuPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 640), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.title = preview ? L("Telecomando LG · Anteprima") : L("Telecomando LG")
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.isMovable = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = host
        sizeObserver = host.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.positionPanel() }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(themeChanged), name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.willSleepNotification, object: nil)
        if !preview { UpdateChecker.shared.start() }
        installEditingMenu()
        updateAppIcon()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.toggle() }
        if !preview && UserDefaults.standard.string(forKey: "pairedHost") == tv.host { tv.connect() }
    }
    private func installEditingMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        let quit = appMenu.addItem(withTitle: L("Esci"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: L("Modifica")); editItem.submenu = edit
        edit.addItem(withTitle: L("Annulla"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Taglia"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Copia"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Incolla"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Seleziona tutto"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
    @objc private func sleeping() { closePanel(); tv.disconnect() }
    @objc private func screenChanged() { positionPanel() }
    @objc private func themeChanged() { DispatchQueue.main.async { self.updateAppIcon() } }
    private func updateAppIcon() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let url = Bundle.main.url(forResource: dark ? "AppIconDark" : "AppIconLight", withExtension: "png"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }
    @objc private func toggle() {
        if panel.isVisible { closePanel() }
        else {
            positionPanel()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            item.button?.highlight(true)
            startClosingMonitors()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    private func positionPanel() {
        guard let button = item.button, let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let content = host.sizeThatFits(in: NSSize(width: 360, height: 10000))
        let size = NSSize(width: 360, height: content.height > 0 ? content.height : 640)
        let frame = MenuPanelPlacement.frame(size: size, anchor: anchor, visible: screen.visibleFrame, screen: screen.frame, topInset: screen.safeAreaInsets.top)
        if !NSEqualRects(panel.frame, frame) { panel.setFrame(frame, display: panel.isVisible) }
    }
    private func closePanel() {
        NotificationCenter.default.post(name: NSNotification.Name("LGTouchpadStop"), object: nil)
        tv.stopPointerMotion()
        panel.orderOut(nil)
        tv.settings = false
        item.button?.highlight(false)
        stopClosingMonitors()
    }
    private func isStatusItemClick(_ event: NSEvent) -> Bool {
        guard let button = item.button, let window = button.window else { return false }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let point = event.window.map { $0.convertPoint(toScreen: event.locationInWindow) } ?? event.locationInWindow
        return frame.contains(point)
    }
    private func startClosingMonitors() {
        stopClosingMonitors()
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.closePanel(); return nil }
                return event
            }
            if self.isStatusItemClick(event) || event.window === self.item.button?.window || event.window === self.panel { return event }
            if event.window?.level == .popUpMenu { return event }
            self.closePanel(); return event
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // Status item events can also arrive through the global monitor.
            // Leave them exclusively to the button action; never queue a stale close.
            guard let self, !self.isStatusItemClick(event) else { return }
            self.closePanel()
        }
    }
    private func stopClosingMonitors() {
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        localClickMonitor = nil; outsideClickMonitor = nil
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !panel.isVisible { toggle() }; return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        stopClosingMonitors(); sizeObserver?.invalidate(); tv.disconnect()
    }
}
