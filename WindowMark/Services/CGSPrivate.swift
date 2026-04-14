import CoreGraphics

// MARK: - CoreGraphics Private API

// Used by JankyBorders, yabai, AeroSpace, and other macOS window managers.
// These functions are part of the CoreGraphics SkyLight framework.

/// Returns the default connection ID for the current process.
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32

/// Orders a window relative to another window in the window server's z-stack.
/// - Parameters:
///   - cid: Connection ID from CGSMainConnectionID()
///   - wid: The window to reorder (use NSWindow.windowNumber)
///   - place: 1 = above, -1 = below, 0 = out (remove)
///   - relativeToWID: The reference window ID (target CGWindowID)
/// - Returns: 0 on success
@_silgen_name("CGSOrderWindow")
func CGSOrderWindow(_ cid: Int32, _ wid: Int32, _ place: Int32, _ relativeToWID: Int32) -> Int32
