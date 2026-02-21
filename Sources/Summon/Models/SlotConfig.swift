import Foundation
import Carbon.HIToolbox

/// A configured "slot" — one terminal app with its hotkey and launch settings.
struct SlotConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var command: String
    /// Fixed working directory used when `useProjectDirectory` is false.
    var workingDirectory: String
    /// When true, detect the working directory from the frontmost app at launch time.
    var useProjectDirectory: Bool
    var hotKey: HotKeyConfig
    var windowSize: WindowSize

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String = NSHomeDirectory(),
        useProjectDirectory: Bool = false,
        hotKey: HotKeyConfig,
        windowSize: WindowSize = .default
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.useProjectDirectory = useProjectDirectory
        self.hotKey = hotKey
        self.windowSize = windowSize
    }

    // Custom decoder so existing slots.json files (which lack `useProjectDirectory`)
    // continue to load correctly — missing key defaults to false.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(UUID.self,         forKey: .id)
        name                = try c.decode(String.self,       forKey: .name)
        command             = try c.decode(String.self,       forKey: .command)
        workingDirectory    = try c.decode(String.self,       forKey: .workingDirectory)
        useProjectDirectory = try c.decodeIfPresent(Bool.self, forKey: .useProjectDirectory) ?? false
        hotKey              = try c.decode(HotKeyConfig.self,  forKey: .hotKey)
        windowSize          = try c.decode(WindowSize.self,    forKey: .windowSize)
    }
}

struct WindowSize: Codable, Hashable {
    var width: Double
    var height: Double

    static let `default` = WindowSize(width: 800, height: 500)
}

/// Hotkey stored using Carbon virtual key codes and Carbon modifier flags.
/// Carbon modifier flags: cmdKey=256, shiftKey=512, optionKey=2048, controlKey=4096
struct HotKeyConfig: Codable, Hashable {
    /// Carbon / IOKit virtual key code (e.g. kVK_ANSI_G = 5)
    var keyCode: UInt32
    /// Carbon modifier flags (e.g. cmdKey | shiftKey = 768)
    var modifierFlags: UInt32

    var displayString: String {
        var parts: [String] = []
        if modifierFlags & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifierFlags & UInt32(optionKey)  != 0 { parts.append("⌥") }
        if modifierFlags & UInt32(shiftKey)   != 0 { parts.append("⇧") }
        if modifierFlags & UInt32(cmdKey)     != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
}

private func keyCodeToString(_ keyCode: UInt32) -> String {
    // Common key code → glyph mapping (Carbon / kVK_ANSI_*)
    let map: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",
    ]
    return map[keyCode] ?? "?"
}
