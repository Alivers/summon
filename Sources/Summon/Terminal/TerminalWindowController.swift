import AppKit
import SwiftTerm

/// Controls the floating window that hosts a single terminal app session.
class TerminalWindowController: NSWindowController {
    private let config: SlotConfig
    private var terminalView: LocalProcessTerminalView?

    /// Called when the hosted process exits (e.g. user quits lazygit).
    var onProcessTerminated: (() -> Void)?

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
        // Use .normal level — we bring it forward with makeKeyAndOrderFront
        // when summoned, and it behaves as a regular window otherwise.
        window.level = .normal
        window.center()

        super.init(window: window)
        setupTerminal()
    }

    required init?(coder: NSCoder) { fatalError("use init(config:)") }

    // MARK: - Setup

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
        // Expand ~ so posix_spawn receives an absolute path
        let dir = (config.workingDirectory as NSString).expandingTildeInPath
        // Single-quote the path to handle spaces; escape any embedded single quotes
        let escapedDir = dir.replacingOccurrences(of: "'", with: #"'\''""#)

        // -l  → login shell, loads ~/.zprofile / ~/.bash_profile (sets up PATH, rbenv, etc.)
        // exec replaces the shell process with the target command (cleaner process tree)
        tv.startProcess(
            executable: shell,
            args: ["-l", "-c", "cd '\(escapedDir)' && exec \(config.command)"],
            environment: nil,
            execName: config.command
        )
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

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // No-op for now; could update window subtitle with dimensions
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        window?.title = title.isEmpty ? config.name : title
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // Reserved for future project-aware features
    }
}
