import Foundation

public enum RunProfile: String, Codable, CaseIterable, Sendable {
    case strict
    case balanced
    case manual

    public var displayName: String {
        switch self {
        case .strict: return "严格"
        case .balanced: return "平衡"
        case .manual: return "完全手动"
        }
    }
}

public enum ThermalLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case unknown
    case nominal
    case fair
    case serious
    case critical

    private var rank: Int {
        switch self {
        case .unknown: return -1
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }

    public static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public var displayName: String {
        switch self {
        case .unknown: return "未知"
        case .nominal: return "正常"
        case .fair: return "升温"
        case .serious: return "严重"
        case .critical: return "临界"
        }
    }
}

public enum PowerSource: String, Codable, Sendable {
    case ac
    case battery
    case unknown

    public var displayName: String {
        switch self {
        case .ac: return "电源"
        case .battery: return "电池"
        case .unknown: return "未知"
        }
    }
}

public enum GuardMode: String, Codable, Sendable {
    case normal
    case active
    case externalEnabled
    case error
}

public enum StopReason: String, Codable, Sendable {
    case none
    case user
    case timer
    case lowBattery
    case thermalSerious
    case thermalCritical
    case externalOverride
    case helperRecovery
    case uninstall
    case commandFailure

    public var displayName: String {
        switch self {
        case .none: return "无"
        case .user: return "手动恢复"
        case .timer: return "定时结束"
        case .lowBattery: return "低电量保护"
        case .thermalSerious: return "温度严重"
        case .thermalCritical: return "温度临界"
        case .externalOverride: return "外部设置变更"
        case .helperRecovery: return "Helper 恢复保护"
        case .uninstall: return "卸载前恢复"
        case .commandFailure: return "系统命令失败"
        }
    }
}

public enum GuardEventKind: String, Codable, Sendable {
    case started
    case fiveMinuteWarning
    case stopped
    case thermalWarning
    case error
}

public struct GuardEvent: Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: GuardEventKind
    public var message: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: GuardEventKind,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.createdAt = createdAt
    }
}

public struct BatterySnapshot: Codable, Equatable, Sendable {
    public var percentage: Int?
    public var source: PowerSource
    public var isCharging: Bool

    public init(percentage: Int?, source: PowerSource, isCharging: Bool) {
        self.percentage = percentage
        self.source = source
        self.isCharging = isCharging
    }

    public static let unknown = BatterySnapshot(percentage: nil, source: .unknown, isCharging: false)
}

public struct SessionRequest: Codable, Equatable, Sendable {
    public var protocolVersion: Int
    public var profile: RunProfile
    public var deadline: Date?
    public var batteryThreshold: Int?
    public var confirmedManualUnlimitedRisk: Bool

    public init(
        protocolVersion: Int = LidGuardConstants.protocolVersion,
        profile: RunProfile,
        deadline: Date?,
        batteryThreshold: Int? = nil,
        confirmedManualUnlimitedRisk: Bool = false
    ) {
        self.protocolVersion = protocolVersion
        self.profile = profile
        self.deadline = deadline
        self.batteryThreshold = batteryThreshold
        self.confirmedManualUnlimitedRisk = confirmedManualUnlimitedRisk
    }
}

public struct UpdateSessionRequest: Codable, Equatable, Sendable {
    public var protocolVersion: Int
    public var deadline: Date?
    public var batteryThreshold: Int?
    public var confirmedManualUnlimitedRisk: Bool

    public init(
        protocolVersion: Int = LidGuardConstants.protocolVersion,
        deadline: Date?,
        batteryThreshold: Int? = nil,
        confirmedManualUnlimitedRisk: Bool = false
    ) {
        self.protocolVersion = protocolVersion
        self.deadline = deadline
        self.batteryThreshold = batteryThreshold
        self.confirmedManualUnlimitedRisk = confirmedManualUnlimitedRisk
    }
}

public struct StopRequest: Codable, Equatable, Sendable {
    public var protocolVersion: Int
    public var reason: StopReason

    public init(
        protocolVersion: Int = LidGuardConstants.protocolVersion,
        reason: StopReason = .user
    ) {
        self.protocolVersion = protocolVersion
        self.reason = reason
    }
}

public struct GuardSession: Codable, Equatable, Sendable {
    public var id: UUID
    public var profile: RunProfile
    public var startedAt: Date
    public var deadline: Date?
    public var batteryThreshold: Int?
    public var fiveMinuteWarningSent: Bool
    public var seriousThermalWarningActive: Bool

    public init(
        id: UUID = UUID(),
        profile: RunProfile,
        startedAt: Date,
        deadline: Date?,
        batteryThreshold: Int?,
        fiveMinuteWarningSent: Bool = false,
        seriousThermalWarningActive: Bool = false
    ) {
        self.id = id
        self.profile = profile
        self.startedAt = startedAt
        self.deadline = deadline
        self.batteryThreshold = batteryThreshold
        self.fiveMinuteWarningSent = fiveMinuteWarningSent
        self.seriousThermalWarningActive = seriousThermalWarningActive
    }
}

public struct PersistedState: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var session: GuardSession?
    public var lastStopReason: StopReason
    public var lastError: String?
    public var lastEvent: GuardEvent?
    public var lastChangedAt: Date

    public init(
        schemaVersion: Int = 1,
        session: GuardSession? = nil,
        lastStopReason: StopReason = .none,
        lastError: String? = nil,
        lastEvent: GuardEvent? = nil,
        lastChangedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.session = session
        self.lastStopReason = lastStopReason
        self.lastError = lastError
        self.lastEvent = lastEvent
        self.lastChangedAt = lastChangedAt
    }
}

public struct StatusSnapshot: Codable, Equatable, Sendable {
    public var protocolVersion: Int
    public var helperVersion: String
    public var mode: GuardMode
    public var sleepDisabled: Bool?
    public var session: GuardSession?
    public var thermalLevel: ThermalLevel
    public var battery: BatterySnapshot
    public var lastStopReason: StopReason
    public var lastError: String?
    public var lastEvent: GuardEvent?
    public var observedAt: Date

    public init(
        protocolVersion: Int = LidGuardConstants.protocolVersion,
        helperVersion: String = LidGuardConstants.helperVersion,
        mode: GuardMode,
        sleepDisabled: Bool?,
        session: GuardSession?,
        thermalLevel: ThermalLevel,
        battery: BatterySnapshot,
        lastStopReason: StopReason,
        lastError: String?,
        lastEvent: GuardEvent?,
        observedAt: Date = Date()
    ) {
        self.protocolVersion = protocolVersion
        self.helperVersion = helperVersion
        self.mode = mode
        self.sleepDisabled = sleepDisabled
        self.session = session
        self.thermalLevel = thermalLevel
        self.battery = battery
        self.lastStopReason = lastStopReason
        self.lastError = lastError
        self.lastEvent = lastEvent
        self.observedAt = observedAt
    }
}

public struct OperationResult: Codable, Equatable, Sendable {
    public var success: Bool
    public var message: String
    public var status: StatusSnapshot

    public init(success: Bool, message: String, status: StatusSnapshot) {
        self.success = success
        self.message = message
        self.status = status
    }
}

public struct SecurityConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var ownerUID: UInt32
    public var clientRequirement: String

    public init(schemaVersion: Int = 1, ownerUID: UInt32, clientRequirement: String) {
        self.schemaVersion = schemaVersion
        self.ownerUID = ownerUID
        self.clientRequirement = clientRequirement
    }
}
