import AppKit

/// Manages the lifecycle and visibility of one running terminal app instance.
class TerminalSession {
    let config: SlotConfig
    private var windowController: TerminalWindowController?

    init(config: SlotConfig) {
        self.config = config
    }

    func launch() {
        let wc = TerminalWindowController(config: config)
        // When the process exits, drop our reference so the next hotkey re-launches fresh
        wc.onProcessTerminated = { [weak self] in
            self?.windowController = nil
        }
        windowController = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Shows if hidden; hides if currently the key window (toggle behaviour).
    func toggleVisibility() {
        guard let wc = windowController, let window = wc.window else {
            launch()
            return
        }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            wc.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func terminate() {
        windowController?.close()
        windowController = nil
    }
}
