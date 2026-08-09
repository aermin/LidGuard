import Foundation
import LidGuardCore

enum InstallerManager {
    static var isHelperInstalled: Bool {
        FileManager.default.fileExists(atPath: LidGuardConstants.helperPath)
            && FileManager.default.fileExists(atPath: LidGuardConstants.launchDaemonPath)
    }

    static func repairHelper() throws {
        guard let script = Bundle.main.path(forResource: "install-helper", ofType: "sh") else {
            throw installerError("安装脚本不在 App Bundle 中")
        }
        try runPrivileged("/bin/bash \(shellQuote(script)) \(shellQuote(Bundle.main.bundlePath))")
    }

    static func uninstallHelper() throws {
        guard let script = Bundle.main.path(forResource: "uninstall-helper", ofType: "sh") else {
            throw installerError("卸载脚本不在 App Bundle 中")
        }
        try runPrivileged("/bin/bash \(shellQuote(script))")
    }

    private static func runPrivileged(_ command: String) throws {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw installerError(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func installerError(_ message: String) -> NSError {
        NSError(
            domain: LidGuardConstants.bundleIdentifier,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
