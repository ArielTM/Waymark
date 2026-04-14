import CoreGraphics

enum HotkeyConfig {
    // Ctrl + Alt + M  (toggle mark on focused window)
    static let toggleMark = (key: CGKeyCode(0x2E), mods: CGEventFlags.maskControl.union(.maskAlternate))

    // Ctrl + Alt + N  (cycle forward)
    static let cycleNext = (key: CGKeyCode(0x2D), mods: CGEventFlags.maskControl.union(.maskAlternate))

    // Ctrl + Alt + Shift + N  (cycle backward)
    static let cyclePrev = (key: CGKeyCode(0x2D), mods: CGEventFlags.maskControl.union(.maskAlternate).union(.maskShift))

    // Ctrl + Alt + L  (show exposé panel)
    static let showExpose = (key: CGKeyCode(0x25), mods: CGEventFlags.maskControl.union(.maskAlternate))

    // Ctrl + Alt + C  (clear watchlist)
    static let clearAll = (key: CGKeyCode(0x08), mods: CGEventFlags.maskControl.union(.maskAlternate))

    /// The set of modifier flags we care about when matching hotkeys.
    /// This masks out irrelevant flags like caps lock, num lock, and function.
    static let relevantModifiersMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
}
