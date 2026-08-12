import Foundation
import LidGuardCore

enum CLIError: Error, LocalizedError {
    case usage(String)

    var errorDescription: String? {
        switch self {
        case let .usage(message): return message
        }
    }
}

struct ParsedArguments {
    let command: String
    let options: [String: String]
    let flags: Set<String>

    init(arguments: [String]) throws {
        guard let command = arguments.first else {
            throw CLIError.usage(usage)
        }
        self.command = command

        var options: [String: String] = [:]
        var flags = Set<String>()
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else {
                throw CLIError.usage("无法识别的参数：\(argument)\n\n\(usage)")
            }
            if [
                "--unlimited",
                "--confirm-risk",
                "--json",
                "--prevent-auto-lock",
                "--allow-auto-lock",
            ].contains(argument) {
                flags.insert(argument)
                index += 1
                continue
            }
            guard index + 1 < arguments.count else {
                throw CLIError.usage("参数 \(argument) 缺少值")
            }
            options[argument] = arguments[index + 1]
            index += 2
        }
        self.options = options
        self.flags = flags
    }
}

let usage = """
合盖守护 LidGuard

用法：
  lidguard status [--json]
  lidguard start --profile <strict|balanced|manual> (--for 2h | --until <ISO8601> | --unlimited) [--battery <10-50|off>] [--prevent-auto-lock] [--confirm-risk]
  lidguard extend (--for 1h | --until <ISO8601> | --unlimited) [--battery <10-50|off>] [--prevent-auto-lock | --allow-auto-lock] [--confirm-risk]
  lidguard stop
  lidguard doctor
"""

func parseProfile(_ value: String?) throws -> RunProfile {
    guard let value, let profile = RunProfile(rawValue: value) else {
        throw CLIError.usage("--profile 必须是 strict、balanced 或 manual")
    }
    return profile
}

func parseBattery(_ value: String?) throws -> Int? {
    guard let value else { return nil }
    if value == "off" { return nil }
    guard let threshold = Int(value) else {
        throw CLIError.usage("--battery 必须是 10-50 或 off")
    }
    return threshold
}

func requestedAutomaticLockPrevention(flags: Set<String>, current: Bool = false) throws -> Bool {
    let prevent = flags.contains("--prevent-auto-lock")
    let allow = flags.contains("--allow-auto-lock")
    guard !(prevent && allow) else {
        throw CLIError.usage("--prevent-auto-lock 与 --allow-auto-lock 不能同时使用")
    }
    if prevent { return true }
    if allow { return false }
    return current
}

func requestedDeadline(
    options: [String: String],
    flags: Set<String>,
    baseDate: Date = Date(),
    extendExisting: Bool = false
) throws -> Date? {
    let selectors = [options["--for"] != nil, options["--until"] != nil, flags.contains("--unlimited")]
    guard selectors.filter({ $0 }).count == 1 else {
        throw CLIError.usage("必须且只能指定 --for、--until 或 --unlimited 之一")
    }
    if let durationText = options["--for"] {
        let duration = try LidGuardTimeParser.duration(durationText)
        return baseDate.addingTimeInterval(duration)
    }
    if let untilText = options["--until"] {
        return try LidGuardTimeParser.date(untilText)
    }
    return nil
}

func printStatus(_ status: StatusSnapshot) {
    let mode: String
    switch status.mode {
    case .normal: mode = "正常合盖休眠"
    case .active: mode = "合盖运行中"
    case .externalEnabled: mode = "外部程序已开启合盖运行"
    case .error: mode = "状态读取失败"
    }
    print("状态：\(mode)")
    print("SleepDisabled：\(status.sleepDisabled.map { $0 ? "1" : "0" } ?? "未知")")
    print("防自动锁屏断言：\(status.automaticLockPreventionActive ? "生效" : "未启用")")
    print("热状态：\(status.thermalLevel.displayName)")
    if let percentage = status.battery.percentage {
        print("电量：\(percentage)%（\(status.battery.source.displayName)）")
    } else {
        print("电量：未知")
    }
    if let session = status.session {
        print("策略：\(session.profile.displayName)")
        if let deadline = session.deadline {
            print("结束：\(ISO8601DateFormatter().string(from: deadline))")
        } else {
            print("结束：不限时")
        }
        print("低电量保护：\(session.batteryThreshold.map { "\($0)%" } ?? "关闭")")
        print("防自动锁屏：\(session.preventAutomaticLock ? "开启" : "关闭")")
    }
    if status.lastStopReason != .none {
        print("最近恢复原因：\(status.lastStopReason.displayName)")
    }
    if let error = status.lastError {
        print("错误：\(error)")
    }
}

func run() throws {
    let parsed = try ParsedArguments(arguments: Array(CommandLine.arguments.dropFirst()))
    let client = HelperClient()

    switch parsed.command {
    case "status":
        let status = try client.fetchStatus()
        if parsed.flags.contains("--json") {
            let data = try LidGuardCoding.makeEncoder(prettyPrinted: true).encode(status)
            print(String(decoding: data, as: UTF8.self))
        } else {
            printStatus(status)
        }
    case "start":
        let profile = try parseProfile(parsed.options["--profile"])
        let deadline = try requestedDeadline(options: parsed.options, flags: parsed.flags)
        let request = SessionRequest(
            profile: profile,
            deadline: deadline,
            batteryThreshold: try parseBattery(parsed.options["--battery"]),
            preventAutomaticLock: try requestedAutomaticLockPrevention(flags: parsed.flags),
            confirmedManualUnlimitedRisk: parsed.flags.contains("--confirm-risk")
        )
        let result = try client.start(request)
        print(result.message)
        printStatus(result.status)
    case "extend":
        let status = try client.fetchStatus()
        guard let session = status.session else { throw PolicyError.noActiveSession }
        let baseDate: Date
        if parsed.options["--for"] != nil {
            baseDate = max(session.deadline ?? Date(), Date())
        } else {
            baseDate = Date()
        }
        let deadline = try requestedDeadline(
            options: parsed.options,
            flags: parsed.flags,
            baseDate: baseDate,
            extendExisting: true
        )
        let threshold: Int?
        if parsed.options.keys.contains("--battery") {
            threshold = try parseBattery(parsed.options["--battery"])
        } else {
            threshold = session.batteryThreshold
        }
        let request = UpdateSessionRequest(
            deadline: deadline,
            batteryThreshold: threshold,
            preventAutomaticLock: try requestedAutomaticLockPrevention(
                flags: parsed.flags,
                current: session.preventAutomaticLock
            ),
            confirmedManualUnlimitedRisk: parsed.flags.contains("--confirm-risk")
        )
        let result = try client.update(request)
        print(result.message)
        printStatus(result.status)
    case "stop":
        let result = try client.stop()
        print(result.message)
        printStatus(result.status)
    case "doctor":
        let status = try client.fetchStatus()
        print("Helper：可用（\(status.helperVersion)）")
        print("协议：\(status.protocolVersion)")
        print("CLI：\(FileManager.default.fileExists(atPath: LidGuardConstants.cliPath) ? "已安装" : "未安装到 /usr/local/bin")")
        printStatus(status)
    case "help", "--help", "-h":
        print(usage)
    default:
        throw CLIError.usage("未知命令：\(parsed.command)\n\n\(usage)")
    }
}

do {
    try run()
} catch let error as CLIError {
    fputs("lidguard: \(error.localizedDescription)\n", stderr)
    exit(3)
} catch let error as HelperClientError {
    fputs("lidguard: \(error.localizedDescription)\n", stderr)
    exit(2)
} catch let error as PolicyError {
    fputs("lidguard: \(error.localizedDescription)\n", stderr)
    exit(3)
} catch {
    fputs("lidguard: \(error.localizedDescription)\n", stderr)
    exit(1)
}
