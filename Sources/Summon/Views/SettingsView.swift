import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var expandedSlotID: UUID?
    @State private var launchAtLogin = LaunchAtLoginHelper.isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // — Permissions
                PermissionsSection()

                // — General
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("General", icon: "gearshape")

                    HStack {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                LaunchAtLoginHelper.isEnabled = newValue
                            }
                        Spacer()
                    }
                    .padding(12)
                    .settingsCard()
                }

                // — Slots
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel("Slots", icon: "terminal")
                        Spacer()
                        Button { addSlot() } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Add slot")
                    }

                    if sessionManager.slots.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "terminal")
                                    .font(.title2)
                                    .foregroundStyle(.quaternary)
                                Text("No slots configured")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                    }

                    ForEach($sessionManager.slots) { $slot in
                        SlotCardView(
                            slot: $slot,
                            isExpanded: expandedSlotID == slot.id,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    expandedSlotID = expandedSlotID == slot.id ? nil : slot.id
                                }
                            },
                            onDelete: { deleteSlot(id: slot.id) },
                            onChanged: { sessionManager.save() },
                            hotkeyConflict: hotkeyConflict(for: slot)
                        )
                    }
                }
            }
            .padding(20)
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            expandedSlotID = newSlot.id
        }
    }

    private func deleteSlot(id: UUID) {
        guard let idx = sessionManager.slots.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
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

// MARK: - Section label

private struct SectionLabel: View {
    let title: String
    let icon: String

    init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Card modifier

extension View {
    fileprivate func settingsCard() -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
            )
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
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Header — always visible
            Button(action: onToggleExpand) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Text(slot.name.isEmpty ? "Untitled" : slot.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(slot.name.isEmpty ? .tertiary : .primary)

                    if !isExpanded && !slot.command.isEmpty {
                        Text(slot.command)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if slot.hotKey.keyCode != 0 || slot.hotKey.modifierFlags != 0 {
                        Text(slot.hotKey.displayString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
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
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Conflicts with \"\(conflict)\"")
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .padding(.leading, 74)
                    }

                    Toggle("Auto-detect working directory", isOn: $slot.useProjectDirectory)
                        .onChange(of: slot.useProjectDirectory) { _ in onChanged() }

                    if !slot.useProjectDirectory {
                        DirectoryPickerField(path: $slot.workingDirectory)
                    }

                    LabeledField("Window") {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text("W").foregroundStyle(.secondary).font(.caption)
                                TextField("", value: $slot.windowSize.width, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    .onSubmit { onChanged() }
                            }
                            HStack(spacing: 4) {
                                Text("H").foregroundStyle(.secondary).font(.caption)
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
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .settingsCard()
        .shadow(color: .black.opacity(isHovering && !isExpanded ? 0.06 : 0.02),
                radius: isHovering && !isExpanded ? 4 : 1, y: 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
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
            .help("Choose directory...")
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
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Permissions", icon: "lock.shield")

            VStack(spacing: 0) {
                PermissionRowView(
                    granted: accessibilityGranted,
                    name: "Accessibility",
                    description: "Detect working directory from frontmost app window.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )

                Divider()
                    .padding(.leading, 36)

                PermissionRowView(
                    granted: nil,
                    name: "Automation (Finder)",
                    description: "macOS will prompt when needed.",
                    settingsURL: nil
                )
            }
            .settingsCard()
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
        .padding(10)
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
