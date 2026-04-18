import Foundation

enum DebugLog {
    private static let queue = DispatchQueue(label: "waymark.debuglog", qos: .utility)

    private static let handle: FileHandle? = {
        let fm = FileManager.default
        guard let libraryURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = libraryURL.appendingPathComponent("Logs/Waymark", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let file = dir.appendingPathComponent("waymark.log")
        if !fm.fileExists(atPath: file.path) {
            fm.createFile(atPath: file.path, contents: nil)
        }
        guard let h = try? FileHandle(forWritingTo: file) else { return nil }
        _ = try? h.seekToEnd()
        return h
    }()

    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func log(_ tag: String, _ message: String) {
        let timestamp = Date()
        queue.async {
            guard let handle else { return }
            let line = "\(formatter.string(from: timestamp)) [\(tag)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            try? handle.write(contentsOf: data)
        }
    }
}
