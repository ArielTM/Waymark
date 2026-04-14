import AppKit
import ApplicationServices

struct WatchedWindow: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    var title: String
    let appName: String
    let bundleIdentifier: String?
    var axElement: AXUIElement?

    var appIcon: NSImage? {
        NSRunningApplication(processIdentifier: pid)?.icon
    }

    var displayTitle: String {
        "\(appName) — \(title)"
    }
}
