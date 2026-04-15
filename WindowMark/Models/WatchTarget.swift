import AppKit

struct ChromeTabInfo {
    let url: String
    let titleAtMark: String
}

enum WatchTarget: Identifiable {
    case window(WatchedWindow)
    case chromeTab(WatchedWindow, ChromeTabInfo)

    var id: String {
        switch self {
        case .window(let w):
            return "win-\(w.id)"
        case .chromeTab(let w, let tab):
            return "tab-\(w.id)-\(tab.url)"
        }
    }

    var displayTitle: String {
        switch self {
        case .window(let w):
            return w.displayTitle
        case .chromeTab(_, let tab):
            return tab.titleAtMark
        }
    }

    var appIcon: NSImage? {
        switch self {
        case .window(let w), .chromeTab(let w, _):
            return w.appIcon
        }
    }

    var parentWindow: WatchedWindow {
        switch self {
        case .window(let w), .chromeTab(let w, _):
            return w
        }
    }

    var windowID: CGWindowID {
        parentWindow.id
    }

    var pid: pid_t {
        parentWindow.pid
    }
}
