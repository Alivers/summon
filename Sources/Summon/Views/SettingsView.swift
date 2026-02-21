import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedSlotID: UUID?
    @State private var isAddingSlot = false

    var body: some View {
        NavigationSplitView {
            List(sessionManager.slots, selection: $selectedSlotID) { slot in
                SlotRow(slot: slot)
                    .tag(slot.id)
            }
            .navigationTitle("Slots")
            .toolbar {
                ToolbarItem {
                    Button { isAddingSlot = true } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button {
                        if let id = selectedSlotID {
                            sessionManager.remove(at: IndexSet(
                                [sessionManager.slots.firstIndex { $0.id == id }].compactMap { $0 }
                            ))
                            selectedSlotID = nil
                        }
                    } label: {
                        Label("Remove", systemImage: "minus")
                    }
                    .disabled(selectedSlotID == nil)
                }
            }
        } detail: {
            if let id = selectedSlotID,
               let slot = sessionManager.slots.first(where: { $0.id == id }) {
                SlotDetail(slot: slot)
                    .environmentObject(sessionManager)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Slot Selected").font(.headline)
                    Text("Select a slot or press + to add one.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 560, minHeight: 340)
        .sheet(isPresented: $isAddingSlot) {
            AddSlotSheet(isPresented: $isAddingSlot)
                .environmentObject(sessionManager)
        }
    }
}

// MARK: - Slot row

private struct SlotRow: View {
    let slot: SlotConfig

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.name).font(.headline)
                Text(slot.command).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(slot.hotKey.displayString)
                .font(.caption.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Slot detail

private struct SlotDetail: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State var draft: SlotConfig

    init(slot: SlotConfig) {
        _draft = State(initialValue: slot)
    }

    var body: some View {
        Form {
            Section("App") {
                TextField("Name", text: $draft.name)
                TextField("Command", text: $draft.command)
                    .font(.system(.body, design: .monospaced))
                Toggle("Auto-detect working directory", isOn: $draft.useProjectDirectory)
                if !draft.useProjectDirectory {
                    DirectoryPickerField(path: $draft.workingDirectory)
                }
            }
            Section("Hotkey") {
                HStack {
                    Text("Shortcut")
                    Spacer()
                    HotKeyRecorderView(hotKey: $draft.hotKey)
                }
            }
            Section("Window") {
                HStack {
                    Text("Width")
                    Spacer()
                    TextField("", value: $draft.windowSize.width, format: .number)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("", value: $draft.windowSize.height, format: .number)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem {
                Button("Save") { sessionManager.update(slot: draft) }
                    .keyboardShortcut("s")
            }
        }
        .navigationTitle(draft.name)
    }
}

// MARK: - Add sheet

private struct AddSlotSheet: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var command = ""
    @State private var workingDirectory = NSHomeDirectory()
    @State private var useProjectDirectory = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Command", text: $command)
                    .font(.system(.body, design: .monospaced))
                Toggle("Auto-detect working directory", isOn: $useProjectDirectory)
                if !useProjectDirectory {
                    DirectoryPickerField(path: $workingDirectory)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Slot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        sessionManager.add(slot: SlotConfig(
                            name: name,
                            command: command,
                            workingDirectory: workingDirectory,
                            useProjectDirectory: useProjectDirectory,
                            hotKey: HotKeyConfig(keyCode: 0, modifierFlags: 0)
                        ))
                        isPresented = false
                    }
                    .disabled(name.isEmpty || command.isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 240)
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
        // Open at the currently configured path if it exists
        panel.directoryURL = URL(fileURLWithPath:
            (path as NSString).expandingTildeInPath
        )

        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Abbreviate path back to ~ where possible
        path = (url.path as NSString).abbreviatingWithTildeInPath
    }
}
