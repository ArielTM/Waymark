import CoreGraphics
import Foundation

final class HotkeyManager: @unchecked Sendable {
    nonisolated(unsafe) var onToggleMark: (@Sendable () -> Void)?
    nonisolated(unsafe) var onCycleNext: (@Sendable () -> Void)?
    nonisolated(unsafe) var onCyclePrev: (@Sendable () -> Void)?
    nonisolated(unsafe) var onShowExpose: (@Sendable () -> Void)?
    nonisolated(unsafe) var onClearAll: (@Sendable () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: selfPtr
        ) else {
            NSLog("[Waymark] Failed to create event tap. Accessibility permission may not be granted.")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Re-enable the tap if macOS disabled it due to timeout.
    func reEnableIfNeeded() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

// C callback — cannot capture Swift context, uses userInfo pointer.
private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Handle tap disabled events
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.reEnableIfNeeded()
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags.intersection(HotkeyConfig.relevantModifiersMask)

    var action: (@Sendable () -> Void)?

    if keyCode == HotkeyConfig.toggleMark.key && flags == HotkeyConfig.toggleMark.mods {
        action = manager.onToggleMark
    } else if keyCode == HotkeyConfig.cyclePrev.key && flags == HotkeyConfig.cyclePrev.mods {
        // Check cyclePrev before cycleNext since cyclePrev has more modifiers (includes Shift)
        action = manager.onCyclePrev
    } else if keyCode == HotkeyConfig.cycleNext.key && flags == HotkeyConfig.cycleNext.mods {
        action = manager.onCycleNext
    } else if keyCode == HotkeyConfig.showExpose.key && flags == HotkeyConfig.showExpose.mods {
        action = manager.onShowExpose
    } else if keyCode == HotkeyConfig.clearAll.key && flags == HotkeyConfig.clearAll.mods {
        action = manager.onClearAll
    }

    if let action {
        DispatchQueue.main.async { action() }
        return nil  // Consume the event
    }

    return Unmanaged.passUnretained(event)
}
