import Foundation
import IOKit.ps
import LidGuardCore

public protocol SensorReading: AnyObject {
    func currentBattery() -> BatterySnapshot
    func currentThermalLevel() -> ThermalLevel
}

public final class SystemSensors: SensorReading {
    public init() {}

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
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .unknown
        }
    }
}
