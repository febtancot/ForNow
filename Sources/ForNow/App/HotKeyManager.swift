import AppKit
import Carbon.HIToolbox
import ForNowKit

/// 通过 Carbon `RegisterEventHotKey` 注册全局快捷键（无需辅助功能授权）。
@MainActor
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?
    private let signature: OSType = 0x464E_4F57 // 'FNOW'

    func register(_ hotKey: GlobalHotKey, action: @escaping () -> Void) {
        unregister()
        self.action = action
        installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(hotKey.keyCode,
                                         carbonModifiers(from: hotKey.modifiers),
                                         hotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &ref)
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("[ForNow] 快捷键注册失败：status=\(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon 热键事件在主线程分发。
            MainActor.assumeIsolated { manager.action?() }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
    }

    private func carbonModifiers(from modifiers: GlobalHotKey.Modifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
