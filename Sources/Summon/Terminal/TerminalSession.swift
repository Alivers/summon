import AppKit

/// Manages the lifecycle and visibility of one running terminal app instance.
class TerminalSession {
    let config: SlotConfig
    private var windowController: TerminalWindowController?

    /// Called when the session ends (process exit or window closed).
    /// SessionManager uses this to remove the session from its registry,
    /// so the next hotkey press goes through resolve() and gets a fresh directory.
    var onSessionTerminated: (() -> Void)?

    init(config: SlotConfig) {
        self.config = config
    }

    func launch() {
        let wc = TerminalWindowController(config: config)
        wc.onProcessTerminated = { [weak self] in
            self?.windowController = nil
            self?.onSessionTerminated?()
        }
        windowController = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Shows if hidden; hides if currently the key window (toggle behaviour).
    /// Does nothing if the session has already been terminated.
    func toggleVisibility() {
        guard let wc = windowController, let window = wc.window else { return }
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
