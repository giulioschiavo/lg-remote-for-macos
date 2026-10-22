import Cocoa
import SwiftUI

enum RemoteInputEvent {
    case move(Double, Double), scroll(Double, Double), click, button(String)
    var isMotion: Bool {
        switch self { case .move, .scroll: return true; default: return false }
    }
    private func number(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(2000, max(-2000, value)).rounded())
    }
    var message: String {
        switch self {
        case .move(let x, let y): return "type:move\ndx:\(number(x))\ndy:\(number(y))\ndown:0\n\n"
        case .scroll(let x, let y): return "type:scroll\ndx:\(number(x))\ndy:\(number(y))\n\n"
        case .click: return "type:click\n\n"
        case .button(let name): return "type:button\nname:\(name)\n\n"
        }
    }
    func merging(_ next: RemoteInputEvent) -> RemoteInputEvent? {
        switch (self, next) {
        case (.move(let x, let y), .move(let nx, let ny)): return .move(x + nx, y + ny)
        case (.scroll(let x, let y), .scroll(let nx, let ny)): return .scroll(x + nx, y + ny)
        default: return nil
        }
    }
}

struct MagicTouchpad: NSViewRepresentable {
    let enabled: Bool
    let sensitivity: Double
    let onMove: (Double, Double) -> Void
    let onClick: () -> Void
    let onScroll: (Double, Double) -> Void
    let onBack: () -> Void
    let onStop: () -> Void
    static func dismantleNSView(_ view: TouchpadSurface, coordinator: ()) { view.deactivate() }
    func makeNSView(context: Context) -> TouchpadSurface { TouchpadSurface() }
    func updateNSView(_ view: TouchpadSurface, context: Context) {
        view.enabled = enabled; view.sensitivity = sensitivity
        view.onMove = onMove; view.onClick = onClick
        view.onScroll = onScroll; view.onBack = onBack; view.onStop = onStop
        view.needsDisplay = true
    }
}

final class TouchpadSurface: NSView {
    var enabled = false { didSet { if oldValue && !enabled { deactivate() } } }
    var sensitivity = 2.0
    var onMove: ((Double, Double) -> Void)?
    var onClick: (() -> Void)?
    var onScroll: ((Double, Double) -> Void)?
    var onBack: (() -> Void)?
    var onStop: (() -> Void)?
    private var tracking: NSTrackingArea?
    private var lastPoint: NSPoint?
    private var hoverPoint: NSPoint?
    private var downPoint: NSPoint?
    private var dragged = false
    private var scrollX: Double = 0
    private var scrollY: Double = 0
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { enabled }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(L("Touchpad della TV"))
        setAccessibilityHelp(L("Muovi il mouse all’interno per spostare il puntatore. Clic per selezionare, due dita per scorrere. Clic destro per tornare indietro."))
        NotificationCenter.default.addObserver(self, selector: #selector(windowResigned(_:)), name: NSWindow.didResignKeyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deactivate), name: NSNotification.Name("LGTouchpadStop"), object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func windowResigned(_ notification: Notification) {
        if let resigned = notification.object as? NSWindow, resigned === window { deactivate() }
    }
    @objc func deactivate() {
        lastPoint = nil; hoverPoint = nil; downPoint = nil
        scrollX = 0; scrollY = 0; needsDisplay = true
        onStop?()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func accessibilityPerformPress() -> Bool {
        guard enabled else { return false }
        onClick?()
        return true
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { deactivate() }
        window?.acceptsMouseMovedEvents = true
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    override func draw(_ dirtyRect: NSRect) {
        let surface = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        NSColor.controlBackgroundColor.withAlphaComponent(enabled ? 0.72 : 0.35).setFill(); surface.fill()
        NSColor.separatorColor.withAlphaComponent(0.45).setStroke(); surface.lineWidth = 1; surface.stroke()
        let caption = NSAttributedString(string: L("Puntatore TV"), attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: enabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
        ])
        let textSize = caption.size()
        caption.draw(at: NSPoint(x: (bounds.width - textSize.width) / 2, y: bounds.midY + 12))
        if let symbol = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .secondaryLabelColor)) {
            symbol.draw(in: NSRect(x: bounds.midX - 11, y: bounds.midY - 23, width: 22, height: 24), from: .zero, operation: .sourceOver, fraction: enabled ? 0.5 : 0.25, respectFlipped: true, hints: nil)
        }
        if enabled, let point = hoverPoint {
            NSColor.controlAccentColor.withAlphaComponent(0.8).setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill()
        }
    }
    override func mouseEntered(with event: NSEvent) {
        guard enabled else { return }
        lastPoint = convert(event.locationInWindow, from: nil)
        hoverPoint = lastPoint; needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) { deactivate() }
    private func move(_ event: NSEvent) {
        guard enabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { deactivate(); return }
        if let previous = lastPoint {
            let dx = Double(point.x - previous.x) * sensitivity
            let dy = Double(point.y - previous.y) * sensitivity
            if abs(dx) + abs(dy) > 0.05 { onMove?(dx, dy) }
        }
        lastPoint = point; hoverPoint = point; needsDisplay = true
    }
    override func mouseMoved(with event: NSEvent) { move(event) }
    override func mouseDown(with event: NSEvent) {
        guard enabled else { return }
        window?.makeFirstResponder(self)
        downPoint = convert(event.locationInWindow, from: nil)
        lastPoint = downPoint; dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        if let downPoint {
            let point = convert(event.locationInWindow, from: nil)
            if hypot(point.x - downPoint.x, point.y - downPoint.y) > 3 { dragged = true }
        }
        move(event)
    }
    override func mouseUp(with event: NSEvent) {
        if enabled && !dragged && downPoint != nil && bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
        downPoint = nil
    }
    override func rightMouseDown(with event: NSEvent) { if enabled { onBack?() } }
    override func scrollWheel(with event: NSEvent) {
        guard enabled, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        let divisor = event.hasPreciseScrollingDeltas ? 20.0 : 1.0
        scrollX -= Double(event.scrollingDeltaX) / divisor
        scrollY -= Double(event.scrollingDeltaY) / divisor
        let x = scrollX.rounded(.towardZero), y = scrollY.rounded(.towardZero)
        scrollX -= x; scrollY -= y
        if x != 0 || y != 0 { onScroll?(x, y) }
    }
}
