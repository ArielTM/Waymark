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
        return ChromeTabInfo(tabId: tabId, url: url, title: title)
    }

    // MARK: - Activate Tab

    /// Activates the tab with the given Chrome tab ID across all Chrome windows.
    /// Brings the containing window to front if the tab is found.
    ///
    /// Note: the `id` comparison is done via `as text` to avoid an AppleScript
    /// integer-coercion quirk where numeric `is` against a 9+ digit tab ID
    /// literal silently fails to match Chrome's Apple-Event-delivered id,
    /// even though both values are the same integer.
    enum ActivateResult {
        case activated
        case notFound
        case callFailed
    }

    func activateTab(tabId: Int) -> ActivateResult {
        // If any window's enumeration errors (Chrome's `-1719 Invalid index`
        // while tab count changes mid-query), we skip that window but track
        // the failure. A "partial|..." result means we cannot confirm the
        // tab is gone, so the caller must not evict.
        let script = """
        tell application "Google Chrome"
            set seenIDs to {}
            set enumErrors to 0
            repeat with w in windows
                try
                    set wIdx to index of w
                    set i to 0
                    repeat with t in tabs of w
                        set i to i + 1
                        set thisID to (id of t as text)
                        set end of seenIDs to (wIdx as text) & ":" & thisID
                        if thisID is "\(tabId)" then
                            set active tab index of w to i
                            set index of w to 1
                            set AppleScript's text item delimiters to ","
                            set idStr to seenIDs as text
                            set AppleScript's text item delimiters to ""
                            return "true|" & idStr
                        end if
                    end repeat
                on error
                    set enumErrors to enumErrors + 1
                end try
            end repeat
            set AppleScript's text item delimiters to ","
            set idStr to seenIDs as text
            set AppleScript's text item delimiters to ""
            if enumErrors > 0 then
                return "partial|" & enumErrors & "|" & idStr
            else
                return "false|" & idStr
            end if
        end tell
        """
        let raw = runAppleScript(script)
        guard let raw else { return .callFailed }
        if raw.hasPrefix("true|") { return .activated }
        if raw.hasPrefix("partial|") { return .callFailed }
        return .notFound
    }

    // MARK: - All Tab IDs (staleness check)

    /// Returns all tab IDs across all Chrome windows. Returns `nil` when the
    /// AppleScript call itself failed (Chrome unresponsive, permission issue,
    /// transient `-1719`, etc.). Callers must treat `nil` as "don't know" and
    /// NOT as "Chrome has no tabs" — the two cases are data-loss-distinct.
    func allTabIDs() -> Set<Int>? {
        let script = """
        tell application "Google Chrome"
            if (count of windows) = 0 then return "OK|"
            set allIDs to {}
            set enumErrors to 0
            repeat with w in windows
                try
                    repeat with t in tabs of w
                        set end of allIDs to (id of t as text)
                    end repeat
                on error
                    set enumErrors to enumErrors + 1
                end try
            end repeat
            if enumErrors > 0 then
                return "PARTIAL|" & enumErrors
            end if
            set AppleScript's text item delimiters to linefeed
            set idString to allIDs as text
            set AppleScript's text item delimiters to ""
            return "OK|" & idString
        end tell
        """
        guard let result = runAppleScript(script) else {
            return nil
        }
        if result.hasPrefix("PARTIAL|") {
            return nil
        }
        guard result.hasPrefix("OK|") else {
            return nil
        }
        let body = String(result.dropFirst("OK|".count))
        if body.isEmpty {
            return []
        }
        return Set(body.split(separator: "\n", omittingEmptySubsequences: true).compactMap { Int($0) })
    }

    // MARK: - Tab Titles (batch lookup by tab ID)

    /// Returns current titles for the given tab IDs across all Chrome windows.
    /// Tabs that no longer exist are simply absent from the result.
    ///
    /// The record-literal delimiter is ASCII US (0x1F) so newlines and tabs
    /// inside titles pass through without collision.
    func tabTitles(for tabIds: Set<Int>) -> [Int: String] {
        guard !tabIds.isEmpty else { return [:] }

        let sep = "\u{001F}"  // ASCII US, safe separator
        let script = """
        tell application "Google Chrome"
            if (count of windows) = 0 then return ""
            set out to {}
            repeat with w in windows
                repeat with t in tabs of w
                    set end of out to (id of t as text) & "\(sep)" & (title of t)
                end repeat
            end repeat
            set AppleScript's text item delimiters to linefeed
            set s to out as text
            set AppleScript's text item delimiters to ""
            return s
        end tell
        """
        guard let result = runAppleScript(script), !result.isEmpty else { return [:] }

        var map: [Int: String] = [:]
        for line in result.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: Character(sep), maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, let id = Int(parts[0]), tabIds.contains(id) else { continue }
            map[id] = String(parts[1])
        }
        return map
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
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
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
