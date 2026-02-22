import AppKit
import Combine
import SwiftUI

// NSApplicationDelegate callbacks always arrive on the main thread.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionManager = SessionManager()
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var slotsCancellable: AnyCancellable?
    private var settingsWindow: NSWindow?

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

        // Auto-open settings on first launch so users see permissions upfront
        if !slotsFileExists {
            openSettings()
        }
    }

    private var slotsFileExists: Bool {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Summon", isDirectory: true)
        let url = dir.appendingPathComponent("slots.json")
        return FileManager.default.fileExists(atPath: url.path)
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
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let view = SettingsView()
                .environmentObject(sessionManager)
                .frame(width: 480, height: 500)
            let hostingController = NSHostingController(rootView: view)
            hostingController.sizingOptions = []
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Summon Settings"
            window.styleMask = [.titled, .closable]
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
