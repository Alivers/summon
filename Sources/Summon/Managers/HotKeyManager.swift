import AppKit
import Carbon.HIToolbox

// Carbon event callback — must be a plain C function, not a closure.
// We use file-scope globals to bridge into Swift.
private var _hotKeyRegistry: [UInt32: UUID] = [:]   // carbonID → slotID
private weak var _sessionManager: SessionManager?

private func carbonHotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    if let slotID = _hotKeyRegistry[hotKeyID.id] {
        Task { @MainActor in
            _sessionManager?.toggle(slotID: slotID)
        }
    }
    return noErr
}

/// Registers global hotkeys for all configured slots using the Carbon Event API.
/// TODO: Consider replacing with soffes/HotKey for a cleaner Swift API.
class HotKeyManager {
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [UUID: EventHotKeyRef] = [:]
    private var nextCarbonID: UInt32 = 1

    init(sessionManager: SessionManager) {
        _sessionManager = sessionManager
        installEventHandler()
        registerAll(slots: sessionManager.slots)
    }

    deinit {
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
        hotKeyRefs.values.forEach { UnregisterEventHotKey($0) }
    }

    func registerAll(slots: [SlotConfig]) {
        hotKeyRefs.values.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        _hotKeyRegistry.removeAll()
        nextCarbonID = 1
        slots.forEach { register(slot: $0) }
    }

    private func register(slot: SlotConfig) {
        let carbonID = nextCarbonID
        nextCarbonID += 1

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCC("SUMN")
        hotKeyID.id = carbonID

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            slot.hotKey.keyCode,
            slot.hotKey.modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs[slot.id] = ref
            _hotKeyRegistry[carbonID] = slot.id
        }
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1, &spec, nil,
            &eventHandlerRef
        )
    }
}

private func fourCC(_ s: String) -> OSType {
    assert(s.count == 4)
    return s.utf8.reduce(0) { OSType($0) << 8 | OSType($1) }
}
