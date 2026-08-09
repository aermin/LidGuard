import Foundation
import LidGuardCore
import os

public final class GuardEngine {
    private let powerController: PowerControlling
    private let stateStore: StateStoring
    private let sensors: SensorReading
    private let now: () -> Date
    private let queue = DispatchQueue(label: "local.huangxiaomin.LidGuard.engine")
    private let logger = Logger(subsystem: LidGuardConstants.bundleIdentifier, category: "engine")
    private var state: PersistedState
    private var timer: DispatchSourceTimer?

    public init(
        powerController: PowerControlling,
        stateStore: StateStoring,
        sensors: SensorReading,
        now: @escaping () -> Date = Date.init,
        startTimer: Bool = true
    ) throws {
        self.powerController = powerController
        self.stateStore = stateStore
        self.sensors = sensors
        self.now = now

        let hadStoredState = stateStore.hasStoredState
        do {
            state = try stateStore.load()
        } catch {
            state = PersistedState(
                lastError: "状态文件无法读取：\(error.localizedDescription)",
                lastEvent: GuardEvent(
                    kind: .error,
                    message: "状态文件损坏，已进入只读观察状态",
                    createdAt: now()
                ),
                lastChangedAt: now()
            )
        }
        try recoverInitialState(hadStoredState: hadStoredState)

        if startTimer {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 2, repeating: 5, leeway: .seconds(1))
            timer.setEventHandler { [weak self] in self?.evaluate() }
            timer.resume()
            self.timer = timer
        }
    }

    deinit {
        timer?.cancel()
    }

    public func status() -> StatusSnapshot {
        queue.sync { makeStatus() }
    }

    public func start(request: SessionRequest) throws -> OperationResult {
        try queue.sync {
            let session = try SessionPolicy.makeSession(from: request, now: now())
            do {
                try powerController.setSleepDisabled(true)
                state.session = session
                state.lastStopReason = .none
                state.lastError = nil
                state.lastEvent = GuardEvent(
                    kind: .started,
                    message: "已开始\(session.profile.displayName)模式的合盖运行",
                    createdAt: now()
                )
                state.lastChangedAt = now()
                try stateStore.save(state)
                logger.info("Started session \(session.id.uuidString, privacy: .public)")
                return OperationResult(success: true, message: "合盖运行已开启", status: makeStatus())
            } catch {
                try? powerController.setSleepDisabled(false)
                recordError(error)
                throw error
            }
        }
    }

    public func update(request: UpdateSessionRequest) throws -> OperationResult {
        try queue.sync {
            guard let session = state.session else { throw PolicyError.noActiveSession }
            state.session = try SessionPolicy.update(session: session, with: request, now: now())
            state.lastError = nil
            state.lastChangedAt = now()
            try stateStore.save(state)
            return OperationResult(success: true, message: "会话保护已更新", status: makeStatus())
        }
    }

    public func stop(request: StopRequest) throws -> OperationResult {
        try queue.sync {
            guard request.protocolVersion == LidGuardConstants.protocolVersion else {
                throw PolicyError.incompatibleProtocol
            }
            try stopInternal(reason: request.reason)
            return OperationResult(success: true, message: "已恢复正常合盖休眠", status: makeStatus())
        }
    }

    public func evaluateNow() {
        queue.sync { evaluate() }
    }

    private func recoverInitialState(hadStoredState: Bool) throws {
        let sleepDisabled = try powerController.readSleepDisabled()

        if !hadStoredState, sleepDisabled {
            state.session = try SessionPolicy.makeSession(
                from: SessionRequest(
                    profile: .balanced,
                    deadline: nil,
                    batteryThreshold: LidGuardConstants.defaultBalancedBatteryThreshold
                ),
                now: now()
            )
            state.lastEvent = GuardEvent(
                kind: .started,
                message: "已接管现有合盖运行状态",
                createdAt: now()
            )
            state.lastChangedAt = now()
            try stateStore.save(state)
            return
        }

        if state.session != nil, !sleepDisabled {
            state.session = nil
            state.lastStopReason = .externalOverride
            state.lastEvent = GuardEvent(
                kind: .stopped,
                message: "检测到外部程序已恢复合盖休眠",
                createdAt: now()
            )
            state.lastChangedAt = now()
            try stateStore.save(state)
        }

        evaluate()
    }

    private func evaluate() {
        do {
            let sleepDisabled = try powerController.readSleepDisabled()

            guard var session = state.session else {
                state.lastError = nil
                return
            }

            guard sleepDisabled else {
                state.session = nil
                state.lastStopReason = .externalOverride
                state.lastEvent = GuardEvent(
                    kind: .stopped,
                    message: "外部设置已关闭合盖运行",
                    createdAt: now()
                )
                state.lastChangedAt = now()
                try stateStore.save(state)
                return
            }

            let thermal = sensors.currentThermalLevel()
            let battery = sensors.currentBattery()
            if let reason = SessionPolicy.stopReason(
                session: session,
                now: now(),
                thermalLevel: thermal,
                battery: battery
            ) {
                try stopInternal(reason: reason)
                return
            }

            var needsSave = false
            if SessionPolicy.shouldSendFiveMinuteWarning(session: session, now: now()) {
                session.fiveMinuteWarningSent = true
                state.lastEvent = GuardEvent(
                    kind: .fiveMinuteWarning,
                    message: "合盖运行将在 5 分钟内自动结束",
                    createdAt: now()
                )
                needsSave = true
            }

            if session.profile == .manual, thermal == .serious {
                if !session.seriousThermalWarningActive {
                    session.seriousThermalWarningActive = true
                    state.lastEvent = GuardEvent(
                        kind: .thermalWarning,
                        message: "系统热状态已达到严重，完全手动模式仍在运行",
                        createdAt: now()
                    )
                    needsSave = true
                }
            } else if session.seriousThermalWarningActive, thermal < .serious {
                session.seriousThermalWarningActive = false
                needsSave = true
            }

            if needsSave {
                state.session = session
                state.lastChangedAt = now()
                try stateStore.save(state)
            }
            state.lastError = nil
        } catch {
            recordError(error)
        }
    }

    private func stopInternal(reason: StopReason) throws {
        do {
            try powerController.setSleepDisabled(false)
            state.session = nil
            state.lastStopReason = reason
            state.lastError = nil
            state.lastEvent = GuardEvent(
                kind: .stopped,
                message: "已恢复正常合盖休眠：\(reason.displayName)",
                createdAt: now()
            )
            state.lastChangedAt = now()
            try stateStore.save(state)
            logger.info("Stopped session: \(reason.rawValue, privacy: .public)")
        } catch {
            recordError(error)
            throw error
        }
    }

    private func recordError(_ error: Error) {
        state.lastError = error.localizedDescription
        state.lastEvent = GuardEvent(
            kind: .error,
            message: error.localizedDescription,
            createdAt: now()
        )
        state.lastChangedAt = now()
        try? stateStore.save(state)
        logger.error("\(error.localizedDescription, privacy: .public)")
    }

    private func makeStatus() -> StatusSnapshot {
        let sleepDisabled: Bool?
        do {
            sleepDisabled = try powerController.readSleepDisabled()
        } catch {
            sleepDisabled = nil
        }

        let mode: GuardMode
        if sleepDisabled == nil {
            mode = .error
        } else if state.session != nil, sleepDisabled == true {
            mode = .active
        } else if state.session == nil, sleepDisabled == true {
            mode = .externalEnabled
        } else {
            mode = .normal
        }

        return StatusSnapshot(
            mode: mode,
            sleepDisabled: sleepDisabled,
            session: state.session,
            thermalLevel: sensors.currentThermalLevel(),
            battery: sensors.currentBattery(),
            lastStopReason: state.lastStopReason,
            lastError: state.lastError,
            lastEvent: state.lastEvent,
            observedAt: now()
        )
    }
}
