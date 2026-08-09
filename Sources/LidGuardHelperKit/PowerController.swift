import Foundation
import LidGuardCore

public protocol PowerControlling: AnyObject {
    func readSleepDisabled() throws -> Bool
    func setSleepDisabled(_ enabled: Bool) throws
}

public enum PowerControllerError: Error, LocalizedError {
    case commandFailed(String)
    case verificationFailed(expected: Bool, actual: Bool)

    public var errorDescription: String? {
        switch self {
        case let .commandFailed(message): return "pmset 执行失败：\(message)"
        case let .verificationFailed(expected, actual):
            return "pmset 验证失败：期望 \(expected ? 1 : 0)，实际 \(actual ? 1 : 0)"
        }
    }
}

public final class PMSetPowerController: PowerControlling {
    public init() {}

    public func readSleepDisabled() throws -> Bool {
        let output = try runPMSet(arguments: ["-g"])
        let pattern = #"(?m)^\s*SleepDisabled\s+([01])\s*$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let valueRange = Range(match.range(at: 1), in: output) else {
            // pmset omits SleepDisabled when it is disabled.
            return false
        }
        return output[valueRange] == "1"
    }

    public func setSleepDisabled(_ enabled: Bool) throws {
        _ = try runPMSet(arguments: ["-a", "disablesleep", enabled ? "1" : "0"])
        let actual = try readSleepDisabled()
        guard actual == enabled else {
            throw PowerControllerError.verificationFailed(expected: enabled, actual: actual)
        }
    }

    private func runPMSet(arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw PowerControllerError.commandFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let errorOutput = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PowerControllerError.commandFailed(message.isEmpty ? output : message)
        }
        return output
    }
}
