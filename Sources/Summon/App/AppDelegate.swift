import AppKit

// NSApplicationDelegate callbacks always arrive on the main thread.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionManager = SessionManager()
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background/menu-bar-only app — no Dock icon
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        hotKeyManager = HotKeyManager(sessionManager: sessionManager, initialSlots: sessionManager.slots)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Summon")

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Summon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
