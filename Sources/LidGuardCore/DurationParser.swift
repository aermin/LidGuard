import Foundation

public enum DurationParserError: Error, LocalizedError {
    case invalidDuration
    case invalidDate

    public var errorDescription: String? {
        switch self {
        case .invalidDuration: return "时长格式无效，请使用 30m、2h 或 1d"
        case .invalidDate: return "结束时间无效，请使用 ISO 8601 格式"
        }
    }
}

public enum LidGuardTimeParser {
    public static func duration(_ value: String) throws -> TimeInterval {
        let pattern = #"^([1-9][0-9]*)([mhd])$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let amountRange = Range(match.range(at: 1), in: value),
              let unitRange = Range(match.range(at: 2), in: value),
              let amount = Double(value[amountRange]) else {
            throw DurationParserError.invalidDuration
        }

        switch value[unitRange] {
        case "m": return amount * 60
        case "h": return amount * 60 * 60
        case "d": return amount * 24 * 60 * 60
        default: throw DurationParserError.invalidDuration
        }
    }

    public static func date(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else {
            throw DurationParserError.invalidDate
        }
        return date
    }
}
