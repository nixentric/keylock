import Cocoa

/// The actual keyboard lock: a session event tap that eats every key event.
/// Nothing persists — the tap dies with the process, so a crash cannot leave you locked out.

func shouldSwallow(_ type: CGEventType) -> Bool {
    switch type {
    case .keyDown, .keyUp, .flagsChanged: return true
    default: return false
    }
}

final class KeyboardTap {
    private var port: CFMachPort?

    /// Returns false when macOS refuses the tap, which in practice means Accessibility
    /// permission has not reached this process yet.
    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, ctx in
                let tap = Unmanaged<KeyboardTap>.fromOpaque(ctx!).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let port = tap.port { CGEvent.tapEnable(tap: port, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                return shouldSwallow(type) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())

        guard let port else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        self.port = nil
    }
}
