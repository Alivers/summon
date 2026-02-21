import AppKit

// TODO: import SwiftTerm — replace placeholder view with LocalProcessTerminalView

/// Controls the floating window that hosts a terminal session.
class TerminalWindowController: NSWindowController {
    private let config: SlotConfig

    init(config: SlotConfig) {
        self.config = config
        let contentRect = NSRect(x: 0, y: 0,
                                 width: config.windowSize.width,
                                 height: config.windowSize.height)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = config.name
        window.isReleasedWhenClosed = false
        window.center()
        // Float above normal windows but below system UI
        window.level = .floating

        super.init(window: window)
        setupTerminalView()
    }

    required init?(coder: NSCoder) { fatalError("use init(config:)") }

    private func setupTerminalView() {
        guard let contentView = window?.contentView else { return }

        // --- Placeholder: replace this block with SwiftTerm integration ---
        let textView = NSTextView(frame: contentView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = false
        textView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        textView.textColor = .green
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.string = """
            [\(config.name)]
            $ \(config.command)
            cwd: \(config.workingDirectory)

            ⚠️  SwiftTerm integration pending — this is a placeholder view.
            """
        contentView.addSubview(textView)
        // --- End placeholder ---
    }
}
