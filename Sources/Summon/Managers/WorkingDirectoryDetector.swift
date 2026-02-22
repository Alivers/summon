import AppKit
import ApplicationServices

/// Detects the working directory from the frontmost app window via the Accessibility API.
///
/// Only runs when a slot has `useProjectDirectory = true`.
/// Requires the user to grant Accessibility permission in System Settings.
@MainActor
struct WorkingDirectoryDetector {

    /// Returns the working directory to use for launching a slot.
    /// Falls back to the slot's fixed `workingDirectory` (or ~ if that's empty).
    static func resolve(for config: SlotConfig) -> String {
        guard config.useProjectDirectory else {
            return config.workingDirectory
        }
        ensureAccessibilityPermission()
        return detectFromFrontmostApp() ?? NSHomeDirectory()
    }

    // MARK: - Detection

    private static func detectFromFrontmostApp() -> String? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            let bundleID = app.bundleIdentifier
        else { return nil }

        // Don't detect from ourselves
        guard bundleID != Bundle.main.bundleIdentifier else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        switch bundleID {
        case "com.apple.finder":
            return finderFrontWindowPath()

        case "com.apple.dt.Xcode":
            // Xcode's AXDocument points to the .xcodeproj/.xcworkspace —
            // the project root is its containing directory
            return axMainWindowDocument(axApp)?.deletingLastPathComponent().path

        case "com.microsoft.VSCode",
             "com.todesktop.230313mzl4w4u92",   // Cursor
             "dev.zed.zed",                      // Zed
             "com.jetbrains.intellij",            // IntelliJ
             "com.jetbrains.AppCode":             // AppCode
            // These editors set AXDocument to the currently open file;
            // use its parent directory
            return axMainWindowDocument(axApp)?.deletingLastPathComponent().path

        default:
            // Best-effort: try AXDocument and take its parent directory
            return axMainWindowDocument(axApp)?.deletingLastPathComponent().path
        }
    }

    // MARK: - AX helpers

    /// Reads the `AXDocument` attribute of the app's main window.
    /// Returns a `file://` URL, or nil if unavailable.
    private static func axMainWindowDocument(_ axApp: AXUIElement) -> URL? {
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, "AXMainWindow" as CFString, &windowRef) == .success,
              let windowRef else { return nil }

        let window = windowRef as! AXUIElement  // safe: success guarantees correct type

        var docRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXDocument" as CFString, &docRef) == .success,
              let docString = docRef as? String,
              let url = URL(string: docString),
              url.isFileURL else { return nil }

        return url
    }

    // MARK: - Finder

    /// Uses AppleScript to get the POSIX path of Finder's frontmost window target folder.
    private static func finderFrontWindowPath() -> String? {
        let script = NSAppleScript(source: """
            tell application "Finder"
                if (count of Finder windows) > 0 then
                    return POSIX path of (target of front Finder window as alias)
                end if
            end tell
            """)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return result?.stringValue
    }

    // MARK: - Permissions

    /// Prompts for Accessibility access the first time it's needed.
    /// The system shows the prompt only once; subsequent calls are no-ops if already trusted.
    private static func ensureAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
