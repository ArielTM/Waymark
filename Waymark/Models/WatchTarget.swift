import AppKit

struct ChromeTabInfo {
    let tabId: Int
    let url: String
    var title: String
}

enum WatchTarget: Identifiable {
    case window(WatchedWindow)
    case chromeTab(WatchedWindow, ChromeTabInfo)

    var id: String {
        switch self {
        case .window(let w):
            return "win-\(w.id)"
        case .chromeTab(_, let tab):
            return "tab-\(tab.tabId)"
        }
    }

    var displayTitle: String {
        switch self {
        case .window(let w):
            return w.displayTitle
        case .chromeTab(_, let tab):
            return tab.title
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
