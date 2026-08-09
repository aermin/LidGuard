import Foundation
import LidGuardCore

enum HelperAuthorizationStatus {
    case current
    case missing
    case outdated
    case unknown
}

enum InstallerManager {
    static var isHelperInstalled: Bool {
        FileManager.default.fileExists(atPath: LidGuardConstants.helperPath)
            && FileManager.default.fileExists(atPath: LidGuardConstants.launchDaemonPath)
    }

    static var helperAuthorizationStatus: HelperAuthorizationStatus {
        guard isHelperInstalled else { return .missing }
        guard let requirement = designatedRequirement(for: Bundle.main.bundlePath),
              let allowedRequirement = installedClientRequirement() else {
            return .unknown
        }
        return allowedRequirement.contains(requirement) ? .current : .outdated
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

    private static func installedClientRequirement() -> String? {
        guard let data = FileManager.default.contents(atPath: LidGuardConstants.securityPath),
              let propertyList = try? PropertyListSerialization.propertyList(
                  from: data,
                  format: nil
              ) as? [String: Any] else {
            return nil
        }
        return propertyList["clientRequirement"] as? String
    }

    private static func designatedRequirement(for path: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dr", "-", path]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        guard let markerRange = output.range(of: "# designated => ") else { return nil }
        return output[markerRange.upperBound...]
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)
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
