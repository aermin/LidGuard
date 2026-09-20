import Foundation
import IOKit.ps
import LidGuardCore

@_silgen_name("notify_register_check")
private func notifyRegisterCheck(_ name: UnsafePointer<CChar>, _ token: UnsafeMutablePointer<Int32>) -> UInt32

@_silgen_name("notify_get_state")
private func notifyGetState(_ token: Int32, _ state: UnsafeMutablePointer<UInt64>) -> UInt32

@_silgen_name("notify_cancel")
private func notifyCancel(_ token: Int32) -> UInt32

public protocol SensorReading: AnyObject {
    func currentBattery() -> BatterySnapshot
    func currentThermalLevel() -> ThermalLevel
}

public final class SystemSensors: SensorReading {
    private let thermalPressureLevel: () -> UInt64?

    public init() {
        thermalPressureLevel = SystemThermalPressure.currentLevel
    }

    public init(thermalPressureLevel: @escaping () -> UInt64?) {
        self.thermalPressureLevel = thermalPressureLevel
    }

    public func currentBattery() -> BatterySnapshot {
        guard let infoReference = IOPSCopyPowerSourcesInfo() else {
            return .unknown
        }
        let info = infoReference.takeRetainedValue()
        guard let listReference = IOPSCopyPowerSourcesList(info) else {
            return .unknown
        }
        let sources = listReference.takeRetainedValue() as Array

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                let transport = description[kIOPSTransportTypeKey] as? String,
                transport == kIOPSInternalType else {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey] as? Int
            let maximum = description[kIOPSMaxCapacityKey] as? Int
            let percentage: Int?
            if let current, let maximum, maximum > 0 {
                percentage = Int((Double(current) / Double(maximum) * 100).rounded())
            } else {
                percentage = current
            }

            let state = description[kIOPSPowerSourceStateKey] as? String
            let powerSource: PowerSource = state == kIOPSBatteryPowerValue ? .battery : .ac
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            return BatterySnapshot(
                percentage: percentage,
                source: powerSource,
                isCharging: isCharging
            )
        }

        return .unknown
    }

    public func currentThermalLevel() -> ThermalLevel {
        let processLevel: ThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: processLevel = .nominal
        case .fair: processLevel = .fair
        case .serious: processLevel = .serious
        case .critical: processLevel = .critical
        @unknown default: processLevel = .unknown
        }

        guard let pressureLevel = thermalPressureLevel(),
              let systemLevel = Self.mapThermalPressure(pressureLevel) else {
            return processLevel
        }
        return max(processLevel, systemLevel)
    }

    public static func mapThermalPressure(_ level: UInt64) -> ThermalLevel? {
        switch level {
        case 0: return .nominal
        case 1: return .fair
        case 2: return .serious
        case 3...: return .critical
        default: return nil
        }
    }
}

private enum SystemThermalPressure {
    private static let notificationName = "com.apple.system.thermalpressurelevel"

    static func currentLevel() -> UInt64? {
        var token: Int32 = 0
        guard notifyRegisterCheck(notificationName, &token) == 0 else {
            return nil
        }
        defer { _ = notifyCancel(token) }

        var state: UInt64 = 0
        guard notifyGetState(token, &state) == 0 else {
            return nil
        }
        return state
    }
}
