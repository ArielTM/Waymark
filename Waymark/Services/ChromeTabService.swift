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
            return (id of t as text) & "\\n" & (URL of t) & "\\n" & (title of t)
        end tell
        """
        guard let result = runAppleScript(script) else { return nil }
        let parts = result.split(separator: "\n", maxSplits: 2)
        guard parts.count == 3, let tabId = Int(parts[0]) else { return nil }
        let url = String(parts[1])
        let title = String(parts[2])
        guard !url.isEmpty else { return nil }
        return ChromeTabInfo(tabId: tabId, url: url, titleAtMark: title)
    }

    // MARK: - Activate Tab

    /// Activates the tab with the given Chrome tab ID across all Chrome windows.
    /// Brings the containing window to front if the tab is found.
    ///
    /// Note: the `id` comparison is done via `as text` to avoid an AppleScript
    /// integer-coercion quirk where numeric `is` against a 9+ digit tab ID
    /// literal silently fails to match Chrome's Apple-Event-delivered id,
    /// even though both values are the same integer.
    func activateTab(tabId: Int) -> Bool {
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                set tabList to tabs of w
                repeat with i from 1 to count of tabList
                    if (id of item i of tabList as text) is "\(tabId)" then
                        set active tab index of w to i
                        set index of w to 1
                        return "true"
                    end if
                end repeat
            end repeat
            return "false"
        end tell
        """
        return runAppleScript(script) == "true"
    }

    // MARK: - All Tab IDs (staleness check)

    /// Returns all tab IDs across all Chrome windows.
    func allTabIDs() -> Set<Int> {
        let script = """
        tell application "Google Chrome"
            if (count of windows) = 0 then return ""
            set allIDs to {}
            repeat with w in windows
                repeat with t in tabs of w
                    set end of allIDs to (id of t as text)
                end repeat
            end repeat
            set AppleScript's text item delimiters to linefeed
            set idString to allIDs as text
            set AppleScript's text item delimiters to ""
            return idString
        end tell
        """
        guard let result = runAppleScript(script), !result.isEmpty else { return [] }
        return Set(result.split(separator: "\n", omittingEmptySubsequences: true).compactMap { Int($0) })
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
