import Foundation

/// Minimal append-only debug log at /tmp/bettertouch.log so we can diagnose
/// input capture without a console attached.
enum Log {
    private static let url = URL(fileURLWithPath: "/tmp/bettertouch.log")
    private static let queue = DispatchQueue(label: "bt.log")

    static func line(_ message: String) {
        queue.async {
            let stamp = ISO8601DateFormatter().string(from: Date())
            let text = "[\(stamp)] \(message)\n"
            guard let data = text.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}
