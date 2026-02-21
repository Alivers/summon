import AppKit
import Combine

// NSApplicationDelegate callbacks always arrive on the main thread.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionManager = SessionManager()
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var slotsCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        rebuildMenu()
        hotKeyManager = HotKeyManager(sessionManager: sessionManager, initialSlots: sessionManager.slots)

        // Keep menu and hotkeys in sync whenever slots change
        slotsCancellable = sessionManager.$slots
            .receive(on: RunLoop.main)
            .sink { [weak self] slots in
                self?.rebuildMenu()
                self?.hotKeyManager?.registerAll(slots: slots)
            }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Summon")
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // One item per configured slot
        if sessionManager.slots.isEmpty {
            let empty = NSMenuItem(title: "No slots configured", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for slot in sessionManager.slots {
                let item = NSMenuItem(
                    title: slot.name,
                    action: #selector(toggleSlot(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = slot.id
                item.toolTip = "\(slot.command)  ·  \(slot.hotKey.displayString)"
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Summon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    @objc private func toggleSlot(_ sender: NSMenuItem) {
        guard let slotID = sender.representedObject as? UUID else { return }
        sessionManager.toggle(slotID: slotID)
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
