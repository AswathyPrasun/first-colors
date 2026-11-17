import OSLog

/// On-device logging only (Console.app / Xcode). Nothing is ever sent off the device.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "KidsColoring"

    static let content = Logger(subsystem: subsystem, category: "content")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
}
