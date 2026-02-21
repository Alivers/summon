import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - Public SwiftUI view

/// A click-to-record hotkey field.
/// Click → enters recording mode (blue border).
/// Press a key combo → saves and exits.
/// Press Esc or click again → cancels.
struct HotKeyRecorderView: View {
    @Binding var hotKey: HotKeyConfig

    var body: some View {
        HotKeyRecorderRepresentable(hotKey: $hotKey)
            .frame(width: 150, height: 24)
    }
}

// MARK: - NSViewRepresentable bridge

private struct HotKeyRecorderRepresentable: NSViewRepresentable {
    @Binding var hotKey: HotKeyConfig

    func makeNSView(context: Context) -> HotKeyRecorderNSView {
        HotKeyRecorderNSView { newKey in hotKey = newKey }
    }

    func updateNSView(_ nsView: HotKeyRecorderNSView, context: Context) {
        // Push external changes (e.g. reset) into the view
        if nsView.currentHotKey != hotKey {
            nsView.currentHotKey = hotKey
        }
    }
}

// MARK: - NSView

final class HotKeyRecorderNSView: NSView {
    var currentHotKey: HotKeyConfig {
        didSet { needsDisplay = true }
    }

    private let onChanged: (HotKeyConfig) -> Void
    private var isRecording = false
    private var liveModifiers: UInt32 = 0   // Carbon flags held right now

    init(onChanged: @escaping (HotKeyConfig) -> Void) {
        self.currentHotKey = HotKeyConfig(keyCode: 0, modifierFlags: 0)
        self.onChanged = onChanged
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    // MARK: Interaction

    override func mouseDown(with event: NSEvent) {
        isRecording ? cancel() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        liveModifiers = 0
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    private func commit(key: HotKeyConfig) {
        isRecording = false
        liveModifiers = 0
        currentHotKey = key
        onChanged(key)
        needsDisplay = true
    }

    private func cancel() {
        isRecording = false
        liveModifiers = 0
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { cancel() }
        return super.resignFirstResponder()
    }

    // MARK: Key events

    /// Show live modifiers while the user is holding them down.
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        liveModifiers = carbonFlags(from: event.modifierFlags)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }

        if event.keyCode == UInt16(kVK_Escape) {
            cancel()
            return
        }

        let mods = carbonFlags(from: event.modifierFlags)
        // Require at least one modifier — bare letters shouldn't be global hotkeys
        guard mods != 0 else { return }

        commit(key: HotKeyConfig(keyCode: UInt32(event.keyCode), modifierFlags: mods))
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)

        // Fill
        let fill: NSColor = isRecording
            ? .controlAccentColor.withAlphaComponent(0.1)
            : .controlBackgroundColor
        fill.setFill()
        path.fill()

        // Border
        let border: NSColor = isRecording ? .controlAccentColor : .separatorColor
        border.setStroke()
        path.lineWidth = isRecording ? 1.5 : 1
        path.stroke()

        // Label
        let label = currentLabel()
        let color: NSColor = isRecording ? .controlAccentColor : .labelColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(
            x: (bounds.width  - sz.width)  / 2,
            y: (bounds.height - sz.height) / 2
        ))
    }

    private func currentLabel() -> String {
        if isRecording {
            let mods = modifierGlyphs(liveModifiers)
            return mods.isEmpty ? "Press shortcut…" : "\(mods)…"
        }
        let isEmpty = currentHotKey.keyCode == 0 && currentHotKey.modifierFlags == 0
        return isEmpty ? "Click to record" : currentHotKey.displayString
    }

    // MARK: Helpers

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift)   { result |= UInt32(shiftKey) }
        if flags.contains(.option)  { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    private func modifierGlyphs(_ carbon: UInt32) -> String {
        var s = ""
        if carbon & UInt32(controlKey) != 0 { s += "⌃" }
        if carbon & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbon & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbon & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }
}
