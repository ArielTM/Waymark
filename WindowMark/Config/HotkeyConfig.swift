import CoreGraphics

enum HotkeyConfig {
    // ⌃⌥M — Control + Option + M  (toggle mark on focused window)
    static let toggleMark = (key: CGKeyCode(0x2E), mods: CGEventFlags.maskControl.union(.maskAlternate))

    // ⌃⌥N — Control + Option + N  (cycle forward)
    static let cycleNext = (key: CGKeyCode(0x2D), mods: CGEventFlags.maskControl.union(.maskAlternate))

    // ⌃⌥⇧N — Control + Option + Shift + N  (cycle backward)
    static let cyclePrev = (key: CGKeyCode(0x2D), mods: CGEventFlags.maskControl.union(.maskAlternate).union(.maskShift))

    // ⌃⌥L — Control + Option + L  (show exposé panel)
    static let showExpose = (key: CGKeyCode(0x25), mods: CGEventFlags.maskControl.union(.maskAlternate))

    // ⌃⌥C — Control + Option + C  (clear watchlist)
    static let clearAll = (key: CGKeyCode(0x08), mods: CGEventFlags.maskControl.union(.maskAlternate))

    /// The set of modifier flags we care about when matching hotkeys.
    /// This masks out irrelevant flags like caps lock, num lock, and function.
    static let relevantModifiersMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
}
