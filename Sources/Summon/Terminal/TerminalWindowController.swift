import AppKit
import SwiftTerm

/// Controls the floating window that hosts a single terminal app session.
class TerminalWindowController: NSWindowController {
    private let config: SlotConfig
    private var terminalView: LocalProcessTerminalView?

    /// Called when the session ends — either the process exits or the user closes the window.
    var onProcessTerminated: (() -> Void)?

    /// Set before calling close() programmatically so windowWillClose doesn't double-fire.
    private var isTerminatingFromProcess = false

    private var frameKey: String { "windowFrame.\(config.id.uuidString)" }

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
        window.level = .normal

        super.init(window: window)
        window.delegate = self
        restoreOrCenterWindow()
        setupTerminal()
    }

    required init?(coder: NSCoder) { fatalError("use init(config:)") }

    // MARK: - Window frame persistence

    private func restoreOrCenterWindow() {
        guard let saved = UserDefaults.standard.string(forKey: frameKey) else {
            window?.center(); return
        }
        let frame = NSRectFromString(saved)
        guard frame.width > 0, frame.height > 0,
              NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) })
        else { window?.center(); return }
        window?.setFrame(frame, display: false)
    }

    private func saveWindowFrame() {
        guard let frame = window?.frame else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: frameKey)
    }

    // MARK: - Terminal setup

    private func setupTerminal() {
        guard let contentView = window?.contentView else { return }
        let tv = LocalProcessTerminalView(frame: contentView.bounds)
        tv.autoresizingMask = [.width, .height]
        tv.processDelegate = self
        contentView.addSubview(tv)
        terminalView = tv
        startProcess(in: tv)
    }

    private func startProcess(in tv: LocalProcessTerminalView) {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let dir = (config.workingDirectory as NSString).expandingTildeInPath
        let escapedDir = dir.replacingOccurrences(of: "'", with: #"'\''""#)
        tv.startProcess(
            executable: shell,
            args: ["-l", "-c", "cd '\(escapedDir)' && exec \(config.command)"],
            environment: nil,
            execName: config.command
        )
    }
}

// MARK: - NSWindowDelegate

extension TerminalWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) { saveWindowFrame() }
    func windowDidResize(_ notification: Notification) { saveWindowFrame() }

    func windowWillClose(_ notification: Notification) {
        // Only handle user-initiated closes (X button).
        // Process-exit closes are handled by processTerminated below.
        guard !isTerminatingFromProcess else { return }
        // Unsubscribe before teardown so we don't get a double callback
        // when the pty closes and the child process gets SIGHUP.
        terminalView?.processDelegate = nil
        terminalView = nil
        onProcessTerminated?()
    }
}

// MARK: - LocalProcessTerminalViewDelegate

extension TerminalWindowController: LocalProcessTerminalViewDelegate {
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async {
            self.isTerminatingFromProcess = true
            self.close()
            self.onProcessTerminated?()
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        window?.title = title.isEmpty ? config.name : title
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
