import Foundation

public enum LidGuardConstants {
    public static let protocolVersion = 2
    public static let helperVersion = "1.1.0"
    public static let bundleIdentifier = "local.huangxiaomin.LidGuard"
    public static let helperLabel = "local.huangxiaomin.LidGuard.helper"
    public static let machServiceName = helperLabel
    public static let applicationSupportDirectory = "/Library/Application Support/LidGuard"
    public static let statePath = applicationSupportDirectory + "/state.json"
    public static let securityPath = applicationSupportDirectory + "/security.json"
    public static let eventPath = applicationSupportDirectory + "/last-event.json"
    public static let helperPath = "/Library/PrivilegedHelperTools/" + helperLabel
    public static let launchDaemonPath = "/Library/LaunchDaemons/" + helperLabel + ".plist"
    public static let cliPath = "/usr/local/bin/lidguard"
    public static let defaultBalancedBatteryThreshold = 20
    public static let strictBatteryThreshold = 30
    public static let minimumBatteryThreshold = 10
    public static let maximumBatteryThreshold = 50
    public static let strictMinimumDuration: TimeInterval = 30 * 60
    public static let strictMaximumDuration: TimeInterval = 8 * 60 * 60
    public static let maximumTimedDuration: TimeInterval = 7 * 24 * 60 * 60
}

public enum LidGuardCoding {
    public static func makeEncoder(prettyPrinted: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
