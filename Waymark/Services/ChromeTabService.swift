import AppKit

@MainActor
final class ChromeTabService {

    private static let chromeBundleID = "com.google.Chrome"

    // MARK: - Get Active Tab

    /// Returns the active tab of the frontmost Chrome window,
    /// or nil if Chrome has no windows or AppleScript fails.
    func getActiveTab() -> ChromeTabInfo? {
        let script = """
        tell application "Google Chrome"
            if (count of windows) = 0 then return ""
            set t to active tab of window 1
            return (URL of t) & "\\n" & (title of t)
        end tell
        """
        guard let result = runAppleScript(script) else { return nil }
        let parts = result.split(separator: "\n", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let url = String(parts[0])
        let title = String(parts[1])
        guard !url.isEmpty else { return nil }
        return ChromeTabInfo(url: url, titleAtMark: title)
    }

    // MARK: - Activate Tab

    /// Activates the tab matching the given URL in Chrome's frontmost window.
    /// Call after WindowManager.focusWindow() has raised the Chrome window.
    func activateTab(url: String) -> Bool {
        let escapedURL = url.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Google Chrome"
            set w to window 1
            set tabList to tabs of w
            repeat with i from 1 to count of tabList
                if URL of item i of tabList is "\(escapedURL)" then
                    set active tab index of w to i
                    return "true"
                end if
            end repeat
            return "false"
        end tell
        """
        return runAppleScript(script) == "true"
    }

    // MARK: - All Tab URLs (staleness check)

    /// Returns all tab URLs across all Chrome windows.
    func allTabURLs() -> Set<String> {
        let script = """
        tell application "Google Chrome"
            if (count of windows) = 0 then return ""
            set allURLs to {}
            repeat with w in windows
                repeat with t in tabs of w
                    set end of allURLs to URL of t
                end repeat
            end repeat
            set AppleScript's text item delimiters to linefeed
            set urlString to allURLs as text
            set AppleScript's text item delimiters to ""
            return urlString
        end tell
        """
        guard let result = runAppleScript(script), !result.isEmpty else { return [] }
        let urls = result.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return Set(urls)
    }

    // MARK: - Detection

    static func isChrome(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier == chromeBundleID
    }

    // MARK: - Private

    private func runAppleScript(_ source: String) -> String? {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let error {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int
            if errorNumber == -1743 {
                print("[Waymark] AppleScript permission denied. Grant Automation access in System Settings.")
            } else {
                print("[Waymark] AppleScript error: \(error)")
            }
            return nil
        }
        return result?.stringValue
    }
}
