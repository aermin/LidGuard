import Foundation
import LidGuardCore
import ServiceManagement

enum LaunchAtLoginManager {
    static func enable() throws {
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } catch {
            try runAppleScript("""
            tell application "System Events"
                if not (exists login item "合盖守护") then
                    make login item at end with properties {name:"合盖守护", path:"/Applications/LidGuard.app", hidden:true}
                end if
            end tell
            """)
        }
    }

    static func disable() throws {
        if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
        _ = try? runAppleScript("""
        tell application "System Events"
            if exists login item "合盖守护" then delete login item "合盖守护"
        end tell
        """)
    }

    static var isEnabled: Bool {
        if SMAppService.mainApp.status == .enabled { return true }
        let script = """
        tell application "System Events"
            return exists login item "合盖守护"
        end tell
        """
        return (try? runAppleScript(script))?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    @discardableResult
    private static func runAppleScript(_ source: String) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: LidGuardConstants.bundleIdentifier,
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
        return output
    }
}
