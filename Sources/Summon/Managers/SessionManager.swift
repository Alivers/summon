import Foundation
import Combine

/// Owns all slot configurations and running terminal sessions.
@MainActor
class SessionManager: ObservableObject {
    @Published var slots: [SlotConfig] = []

    private var sessions: [UUID: TerminalSession] = [:]

    private let configURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Summon", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("slots.json")
    }()

    init() {
        load()
    }

    // MARK: - Session control

    func toggle(slotID: UUID) {
        guard let slot = slots.first(where: { $0.id == slotID }) else { return }
        if let session = sessions[slotID] {
            session.toggleVisibility()
        } else {
            // Resolve working directory before creating the session —
            // must happen while the previous app is still frontmost.
            var launchConfig = slot
            launchConfig.workingDirectory = WorkingDirectoryDetector.resolve(for: slot)
            let session = TerminalSession(config: launchConfig)
            sessions[slotID] = session
            session.launch()
        }
    }

    // MARK: - Slot CRUD

    func add(slot: SlotConfig) {
        slots.append(slot)
        save()
    }

    func update(slot: SlotConfig) {
        guard let idx = slots.firstIndex(where: { $0.id == slot.id }) else { return }
        slots[idx] = slot
        save()
    }

    func remove(at offsets: IndexSet) {
        offsets.map { slots[$0].id }.forEach { sessions[$0]?.terminate() }
        slots.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(slots) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: configURL),
            let decoded = try? JSONDecoder().decode([SlotConfig].self, from: data)
        else {
            slots = .defaults
            return
        }
        slots = decoded
    }
}

extension [SlotConfig] {
    /// Sensible defaults shown on first launch.
    static let defaults: [SlotConfig] = [
        SlotConfig(
            name: "Claude Code",
            command: "claude",
            useProjectDirectory: true,                              // auto-detect project dir
            hotKey: HotKeyConfig(keyCode: 8, modifierFlags: 768)   // ⌘⇧C
        ),
        SlotConfig(
            name: "lazygit",
            command: "lazygit",
            useProjectDirectory: true,                              // auto-detect project dir
            hotKey: HotKeyConfig(keyCode: 5, modifierFlags: 768)   // ⌘⇧G
        ),
        SlotConfig(
            name: "k9s",
            command: "k9s",
            hotKey: HotKeyConfig(keyCode: 40, modifierFlags: 768)  // ⌘⇧K
        ),
    ]
}
