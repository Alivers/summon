import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var expandedSlotID: UUID?
    @State private var launchAtLogin = LaunchAtLoginHelper.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Summon Settings")
                    .font(.headline)
                Spacer()
                Button {
                    addSlot()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add slot")
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            PermissionsSection()
                .padding(.horizontal)
                .padding(.bottom, 8)

            HStack {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLoginHelper.isEnabled = newValue
                    }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Slot cards
            ScrollView {
                VStack(spacing: 8) {
                    HStack {
                        Text("Slots")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    ForEach($sessionManager.slots) { $slot in
                        SlotCardView(
                            slot: $slot,
                            isExpanded: expandedSlotID == slot.id,
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedSlotID == slot.id {
                                        expandedSlotID = nil
                                    } else {
                                        expandedSlotID = slot.id
                                    }
                                }
                            },
                            onDelete: {
                                deleteSlot(id: slot.id)
                            },
                            onChanged: {
                                sessionManager.save()
                            },
                            hotkeyConflict: hotkeyConflict(for: slot)
                        )
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .onChange(of: expandedSlotID) { _ in
            sessionManager.save()
        }
    }

    private func addSlot() {
        let newSlot = SlotConfig(
            name: "",
            command: "",
            hotKey: HotKeyConfig(keyCode: 0, modifierFlags: 0)
        )
        sessionManager.slots.append(newSlot)
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedSlotID = newSlot.id
        }
    }

    private func deleteSlot(id: UUID) {
        guard let idx = sessionManager.slots.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSlotID == id { expandedSlotID = nil }
            sessionManager.remove(at: IndexSet(integer: idx))
        }
    }

    private func hotkeyConflict(for slot: SlotConfig) -> String? {
        guard slot.hotKey.keyCode != 0 || slot.hotKey.modifierFlags != 0 else { return nil }
        return sessionManager.slots.first(where: {
            $0.id != slot.id
            && $0.hotKey.keyCode == slot.hotKey.keyCode
            && $0.hotKey.modifierFlags == slot.hotKey.modifierFlags
        })?.name
    }
}

// MARK: - Slot card

private struct SlotCardView: View {
    @Binding var slot: SlotConfig
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onChanged: () -> Void
    let hotkeyConflict: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header — always visible
            Button(action: onToggleExpand) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(slot.name.isEmpty ? "Untitled" : slot.name)
                            .font(.headline)
                            .foregroundStyle(slot.name.isEmpty ? .secondary : .primary)
                        Text(slot.command.isEmpty ? "no command" : slot.command)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if slot.hotKey.keyCode != 0 || slot.hotKey.modifierFlags != 0 {
                        Text(slot.hotKey.displayString)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 12) {
                    LabeledField("Name") {
                        TextField("Name", text: $slot.name)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { onChanged() }
                    }

                    LabeledField("Command") {
                        TextField("Command", text: $slot.command)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { onChanged() }
                    }

                    LabeledField("Shortcut") {
                        HStack(spacing: 6) {
                            HotKeyRecorderView(hotKey: $slot.hotKey)
                                .onChange(of: slot.hotKey) { _ in onChanged() }
                            if slot.hotKey.keyCode != 0 || slot.hotKey.modifierFlags != 0 {
                                Button {
                                    slot.hotKey = HotKeyConfig(keyCode: 0, modifierFlags: 0)
                                    onChanged()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Clear shortcut")
                            }
                        }
                    }

                    if let conflict = hotkeyConflict {
                        Text("Conflicts with \"\(conflict)\"")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Toggle("Auto-detect working directory", isOn: $slot.useProjectDirectory)
                        .onChange(of: slot.useProjectDirectory) { _ in onChanged() }

                    if !slot.useProjectDirectory {
                        DirectoryPickerField(path: $slot.workingDirectory)
                    }

                    LabeledField("Window") {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text("W").foregroundStyle(.secondary)
                                TextField("", value: $slot.windowSize.width, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    .onSubmit { onChanged() }
                            }
                            HStack(spacing: 4) {
                                Text("H").foregroundStyle(.secondary)
                                TextField("", value: $slot.windowSize.height, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    .onSubmit { onChanged() }
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    }
                }
                .padding(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }
}

// MARK: - Labeled field helper

private struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(.secondary)
            content
        }
    }
}

// MARK: - Directory picker field

/// A monospaced text field with a folder button that opens NSOpenPanel.
private struct DirectoryPickerField: View {
    @Binding var path: String

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $path)
                .font(.system(.body, design: .monospaced))
            Button {
                pickDirectory()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Choose directory…")
        }
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Working Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.directoryURL = URL(fileURLWithPath:
            (path as NSString).expandingTildeInPath
        )

        guard panel.runModal() == .OK, let url = panel.url else { return }
        path = (url.path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - Permissions section

private struct PermissionsSection: View {
    @State private var accessibilityGranted = AXIsProcessTrusted()
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Permissions")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            PermissionRowView(
                granted: accessibilityGranted,
                name: "Accessibility",
                description: "Detect working directory from frontmost app window.",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )

            PermissionRowView(
                granted: nil,
                name: "Automation (Finder)",
                description: "macOS will prompt when needed.",
                settingsURL: nil
            )
        }
        .onReceive(timer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }
}

private struct PermissionRowView: View {
    let granted: Bool?
    let name: String
    let description: String
    let settingsURL: String?

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
                .font(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.body.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let urlString = settingsURL {
                Button("Open Settings") {
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch granted {
        case true:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case false:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case nil:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
        }
    }
}
