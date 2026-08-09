import Foundation

public enum PolicyError: Error, Equatable, LocalizedError {
    case incompatibleProtocol
    case deadlineInPast
    case strictRequiresDeadline
    case strictDurationOutOfRange
    case timedDurationTooLong
    case invalidBatteryThreshold
    case strictBatteryThresholdIsFixed
    case manualUnlimitedRiskNotConfirmed
    case noActiveSession

    public var errorDescription: String? {
        switch self {
        case .incompatibleProtocol: return "协议版本不兼容"
        case .deadlineInPast: return "结束时间必须晚于当前时间"
        case .strictRequiresDeadline: return "严格模式必须设置结束时间"
        case .strictDurationOutOfRange: return "严格模式时长必须在 30 分钟至 8 小时之间"
        case .timedDurationTooLong: return "定时时长不能超过 7 天，请改用不限时"
        case .invalidBatteryThreshold: return "低电量阈值必须在 10% 至 50% 之间"
        case .strictBatteryThresholdIsFixed: return "严格模式的低电量阈值固定为 30%"
        case .manualUnlimitedRiskNotConfirmed: return "完全手动不限时模式必须确认密闭空间运行风险"
        case .noActiveSession: return "当前没有合盖运行会话"
        }
    }
}

public enum SessionPolicy {
    public static func makeSession(from request: SessionRequest, now: Date = Date()) throws -> GuardSession {
        guard request.protocolVersion == LidGuardConstants.protocolVersion else {
            throw PolicyError.incompatibleProtocol
        }

        let deadline = try validateDeadline(request.deadline, profile: request.profile, now: now)
        let batteryThreshold = try normalizedBatteryThreshold(
            request.batteryThreshold,
            profile: request.profile
        )

        if request.profile == .manual,
           deadline == nil,
           !request.confirmedManualUnlimitedRisk {
            throw PolicyError.manualUnlimitedRiskNotConfirmed
        }

        return GuardSession(
            profile: request.profile,
            startedAt: now,
            deadline: deadline,
            batteryThreshold: batteryThreshold
        )
    }

    public static func update(
        session: GuardSession,
        with request: UpdateSessionRequest,
        now: Date = Date()
    ) throws -> GuardSession {
        guard request.protocolVersion == LidGuardConstants.protocolVersion else {
            throw PolicyError.incompatibleProtocol
        }

        let deadline = try validateDeadline(request.deadline, profile: session.profile, now: now)
        let batteryThreshold = try normalizedBatteryThreshold(
            request.batteryThreshold,
            profile: session.profile
        )

        if session.profile == .manual,
           deadline == nil,
           !request.confirmedManualUnlimitedRisk {
            throw PolicyError.manualUnlimitedRiskNotConfirmed
        }

        var updated = session
        updated.deadline = deadline
        updated.batteryThreshold = batteryThreshold
        updated.fiveMinuteWarningSent = false
        return updated
    }

    public static func stopReason(
        session: GuardSession,
        now: Date,
        thermalLevel: ThermalLevel,
        battery: BatterySnapshot
    ) -> StopReason? {
        if let deadline = session.deadline, now >= deadline {
            return .timer
        }

        if thermalLevel == .critical {
            return .thermalCritical
        }

        if thermalLevel == .serious, session.profile != .manual {
            return .thermalSerious
        }

        if let threshold = session.batteryThreshold,
           battery.source == .battery,
           !battery.isCharging,
           let percentage = battery.percentage,
           percentage <= threshold {
            return .lowBattery
        }

        return nil
    }

    public static func shouldSendFiveMinuteWarning(session: GuardSession, now: Date) -> Bool {
        guard !session.fiveMinuteWarningSent, let deadline = session.deadline else {
            return false
        }
        let remaining = deadline.timeIntervalSince(now)
        return remaining > 0 && remaining <= 5 * 60
    }

    private static func validateDeadline(
        _ deadline: Date?,
        profile: RunProfile,
        now: Date
    ) throws -> Date? {
        if profile == .strict, deadline == nil {
            throw PolicyError.strictRequiresDeadline
        }

        guard let deadline else {
            return nil
        }

        let duration = deadline.timeIntervalSince(now)
        guard duration > 0 else {
            throw PolicyError.deadlineInPast
        }

        if profile == .strict {
            guard duration >= LidGuardConstants.strictMinimumDuration - 2,
                  duration <= LidGuardConstants.strictMaximumDuration else {
                throw PolicyError.strictDurationOutOfRange
            }
        } else if duration > LidGuardConstants.maximumTimedDuration {
            throw PolicyError.timedDurationTooLong
        }

        return deadline
    }

    private static func normalizedBatteryThreshold(
        _ requested: Int?,
        profile: RunProfile
    ) throws -> Int? {
        switch profile {
        case .strict:
            if let requested, requested != LidGuardConstants.strictBatteryThreshold {
                throw PolicyError.strictBatteryThresholdIsFixed
            }
            return LidGuardConstants.strictBatteryThreshold
        case .balanced:
            let threshold = requested ?? LidGuardConstants.defaultBalancedBatteryThreshold
            try validateBatteryThreshold(threshold)
            return threshold
        case .manual:
            guard let requested else { return nil }
            try validateBatteryThreshold(requested)
            return requested
        }
    }

    private static func validateBatteryThreshold(_ threshold: Int) throws {
        guard (LidGuardConstants.minimumBatteryThreshold...LidGuardConstants.maximumBatteryThreshold)
            .contains(threshold) else {
            throw PolicyError.invalidBatteryThreshold
        }
    }
}
