import Foundation
import LidGuardCore
import LidGuardHelperKit

enum TestFailure: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case let .failed(message): return message
        }
    }
}

final class FakePowerController: PowerControlling {
    var sleepDisabled: Bool
    var setValues: [Bool] = []

    init(sleepDisabled: Bool) {
        self.sleepDisabled = sleepDisabled
    }

    func readSleepDisabled() throws -> Bool { sleepDisabled }

    func setSleepDisabled(_ enabled: Bool) throws {
        setValues.append(enabled)
        sleepDisabled = enabled
    }
}

final class MemoryStateStore: StateStoring {
    var storedState: PersistedState?
    var hasStoredState: Bool { storedState != nil }

    init(_ state: PersistedState? = nil) {
        storedState = state
    }

    func load() throws -> PersistedState { storedState ?? PersistedState() }
    func save(_ state: PersistedState) throws { storedState = state }
}

final class FakeSensors: SensorReading {
    var battery: BatterySnapshot = .unknown
    var thermal: ThermalLevel = .nominal

    func currentBattery() -> BatterySnapshot { battery }
    func currentThermalLevel() -> ThermalLevel { thermal }
}

final class TestRunner {
    private(set) var passed = 0
    private(set) var failed = 0

    func run(_ name: String, _ test: () throws -> Void) {
        do {
            try test()
            passed += 1
            print("PASS \(name)")
        } catch {
            failed += 1
            print("FAIL \(name): \(error.localizedDescription)")
        }
    }

    func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure.failed(message) }
    }

    func expectThrows<T: Error & Equatable>(
        _ expected: T,
        _ operation: () throws -> Void
    ) throws {
        do {
            try operation()
            throw TestFailure.failed("Expected \(expected), but no error was thrown")
        } catch let error as T {
            try expect(error == expected, "Expected \(expected), got \(error)")
        }
    }
}

let runner = TestRunner()

runner.run("strict requires deadline") {
    try runner.expectThrows(PolicyError.strictRequiresDeadline) {
        _ = try SessionPolicy.makeSession(from: SessionRequest(profile: .strict, deadline: nil))
    }
}

runner.run("strict normalizes battery") {
    let now = Date(timeIntervalSince1970: 1_000)
    let session = try SessionPolicy.makeSession(
        from: SessionRequest(profile: .strict, deadline: now.addingTimeInterval(60 * 60)),
        now: now
    )
    try runner.expect(session.batteryThreshold == 30, "Strict threshold must be 30")
}

runner.run("strict rejects short duration") {
    let now = Date(timeIntervalSince1970: 1_000)
    try runner.expectThrows(PolicyError.strictDurationOutOfRange) {
        _ = try SessionPolicy.makeSession(
            from: SessionRequest(profile: .strict, deadline: now.addingTimeInterval(10 * 60)),
            now: now
        )
    }
}

runner.run("balanced defaults to twenty percent") {
    let session = try SessionPolicy.makeSession(
        from: SessionRequest(profile: .balanced, deadline: nil)
    )
    try runner.expect(session.batteryThreshold == 20, "Balanced threshold must default to 20")
}

runner.run("balanced accepts custom battery threshold") {
    let session = try SessionPolicy.makeSession(
        from: SessionRequest(profile: .balanced, deadline: nil, batteryThreshold: 35)
    )
    try runner.expect(session.batteryThreshold == 35, "Balanced threshold must preserve selection")
}

runner.run("manual accepts enabled battery threshold") {
    let session = try SessionPolicy.makeSession(
        from: SessionRequest(
            profile: .manual,
            deadline: Date().addingTimeInterval(60 * 60),
            batteryThreshold: 25
        )
    )
    try runner.expect(session.batteryThreshold == 25, "Manual threshold must preserve selection")
}

runner.run("manual unlimited requires confirmation") {
    try runner.expectThrows(PolicyError.manualUnlimitedRiskNotConfirmed) {
        _ = try SessionPolicy.makeSession(from: SessionRequest(profile: .manual, deadline: nil))
    }
}

runner.run("manual serious warns and critical stops") {
    let session = try SessionPolicy.makeSession(
        from: SessionRequest(profile: .manual, deadline: Date().addingTimeInterval(60 * 60))
    )
    try runner.expect(
        SessionPolicy.stopReason(
            session: session,
            now: Date(),
            thermalLevel: .serious,
            battery: .unknown
        ) == nil,
        "Manual serious state must not stop"
    )
    try runner.expect(
        SessionPolicy.stopReason(
            session: session,
            now: Date(),
            thermalLevel: .critical,
            battery: .unknown
        ) == .thermalCritical,
        "Critical state must stop"
    )
}

runner.run("low battery only triggers while discharging") {
    let session = try SessionPolicy.makeSession(
        from: SessionRequest(profile: .balanced, deadline: nil, batteryThreshold: 20)
    )
    try runner.expect(
        SessionPolicy.stopReason(
            session: session,
            now: Date(),
            thermalLevel: .nominal,
            battery: BatterySnapshot(percentage: 10, source: .ac, isCharging: true)
        ) == nil,
        "AC power must not trigger low battery stop"
    )
    try runner.expect(
        SessionPolicy.stopReason(
            session: session,
            now: Date(),
            thermalLevel: .nominal,
            battery: BatterySnapshot(percentage: 20, source: .battery, isCharging: false)
        ) == .lowBattery,
        "Battery threshold must stop"
    )
}

runner.run("time parsing") {
    let thirtyMinutes = try LidGuardTimeParser.duration("30m")
    let twoHours = try LidGuardTimeParser.duration("2h")
    let oneDay = try LidGuardTimeParser.duration("1d")
    try runner.expect(thirtyMinutes == 1_800, "30m parse failed")
    try runner.expect(twoHours == 7_200, "2h parse failed")
    try runner.expect(oneDay == 86_400, "1d parse failed")
    _ = try LidGuardTimeParser.date("2026-08-10T08:00:00+08:00")
}

runner.run("first launch imports existing state") {
    let power = FakePowerController(sleepDisabled: true)
    let engine = try GuardEngine(
        powerController: power,
        stateStore: MemoryStateStore(),
        sensors: FakeSensors(),
        startTimer: false
    )
    let status = engine.status()
    try runner.expect(status.mode == .active, "Imported mode must be active")
    try runner.expect(status.session?.profile == .balanced, "Imported profile must be balanced")
    try runner.expect(status.session?.deadline == nil, "Imported session must be unlimited")
    try runner.expect(status.session?.batteryThreshold == 20, "Imported threshold must be 20")
    try runner.expect(power.setValues.isEmpty, "Import must not rewrite pmset")
}

runner.run("start and stop toggle only sleep disabled") {
    let power = FakePowerController(sleepDisabled: false)
    let engine = try GuardEngine(
        powerController: power,
        stateStore: MemoryStateStore(PersistedState()),
        sensors: FakeSensors(),
        startTimer: false
    )
    _ = try engine.start(request: SessionRequest(profile: .balanced, deadline: nil))
    _ = try engine.stop(request: StopRequest())
    try runner.expect(power.setValues == [true, false], "Expected only true then false writes")
}

runner.run("timer stops session") {
    var current = Date(timeIntervalSince1970: 10_000)
    let power = FakePowerController(sleepDisabled: false)
    let engine = try GuardEngine(
        powerController: power,
        stateStore: MemoryStateStore(PersistedState()),
        sensors: FakeSensors(),
        now: { current },
        startTimer: false
    )
    _ = try engine.start(
        request: SessionRequest(profile: .balanced, deadline: current.addingTimeInterval(60))
    )
    current = current.addingTimeInterval(61)
    engine.evaluateNow()
    try runner.expect(!power.sleepDisabled, "Timer must restore sleep")
    try runner.expect(engine.status().lastStopReason == .timer, "Stop reason must be timer")
}

runner.run("manual serious warning then critical stop") {
    let sensors = FakeSensors()
    let power = FakePowerController(sleepDisabled: false)
    let engine = try GuardEngine(
        powerController: power,
        stateStore: MemoryStateStore(PersistedState()),
        sensors: sensors,
        startTimer: false
    )
    _ = try engine.start(
        request: SessionRequest(profile: .manual, deadline: Date().addingTimeInterval(60 * 60))
    )
    sensors.thermal = .serious
    engine.evaluateNow()
    try runner.expect(power.sleepDisabled, "Serious manual mode must continue")
    try runner.expect(engine.status().lastEvent?.kind == .thermalWarning, "Must record warning")
    sensors.thermal = .critical
    engine.evaluateNow()
    try runner.expect(!power.sleepDisabled, "Critical state must restore sleep")
}

runner.run("external override ends session without reasserting") {
    let power = FakePowerController(sleepDisabled: false)
    let engine = try GuardEngine(
        powerController: power,
        stateStore: MemoryStateStore(PersistedState()),
        sensors: FakeSensors(),
        startTimer: false
    )
    _ = try engine.start(request: SessionRequest(profile: .balanced, deadline: nil))
    power.sleepDisabled = false
    engine.evaluateNow()
    try runner.expect(engine.status().session == nil, "External override must clear session")
    try runner.expect(engine.status().lastStopReason == .externalOverride, "Wrong stop reason")
    try runner.expect(power.setValues == [true], "Engine must not fight external override")
}

runner.run("low battery stops balanced session") {
    let sensors = FakeSensors()
    let power = FakePowerController(sleepDisabled: false)
    let engine = try GuardEngine(
        powerController: power,
        stateStore: MemoryStateStore(PersistedState()),
        sensors: sensors,
        startTimer: false
    )
    _ = try engine.start(request: SessionRequest(profile: .balanced, deadline: nil))
    sensors.battery = BatterySnapshot(percentage: 20, source: .battery, isCharging: false)
    engine.evaluateNow()
    try runner.expect(!power.sleepDisabled, "Low battery must restore sleep")
    try runner.expect(engine.status().lastStopReason == .lowBattery, "Wrong stop reason")
}

print("\nTests: \(runner.passed) passed, \(runner.failed) failed")
exit(runner.failed == 0 ? 0 : 1)
