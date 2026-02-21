import AppKit
import SwiftTerm

/// Controls the floating window that hosts a single terminal app session.
class TerminalWindowController: NSWindowController {
    private let config: SlotConfig
    private var terminalView: LocalProcessTerminalView?

    /// Called when the hosted process exits (e.g. user quits lazygit).
    var onProcessTerminated: (() -> Void)?

    // UserDefaults key for this slot's saved window frame
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
        guard
            let saved = UserDefaults.standard.string(forKey: frameKey)
        else {
            window?.center()
            return
        }
        let frame = NSRectFromString(saved)
        // Validate: non-zero and at least partially on a screen
        guard frame.width > 0, frame.height > 0,
              NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) })
        else {
            window?.center()
            return
        }
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
    func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveWindowFrame()
    }
}

// MARK: - LocalProcessTerminalViewDelegate

extension TerminalWindowController: LocalProcessTerminalViewDelegate {
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async {
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
