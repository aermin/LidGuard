import Foundation
import IOKit.pwr_mgt
import LidGuardCore
import os

public protocol AutomaticLockControlling: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public enum AutomaticLockControllerError: Error, LocalizedError {
    case displayAssertionFailed(IOReturn)
    case userActivityFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case let .displayAssertionFailed(code):
            return "无法创建显示器防休眠断言：\(code)"
        case let .userActivityFailed(code):
            return "无法刷新用户活跃状态：\(code)"
        }
    }
}

public final class IOKitAutomaticLockController: AutomaticLockControlling {
    private let assertionName = "LidGuard automatic lock prevention" as CFString
    private let queue = DispatchQueue(label: "local.huangxiaomin.LidGuard.automatic-lock")
    private let logger = Logger(subsystem: LidGuardConstants.bundleIdentifier, category: "automatic-lock")
    private var displayAssertionID = IOPMAssertionID(0)
    private var activityAssertionID = IOPMAssertionID(0)
    private var timer: DispatchSourceTimer?

    public init() {}

    deinit {
        try? setEnabled(false)
    }

    public var isEnabled: Bool {
        queue.sync { displayAssertionID != 0 && timer != nil }
    }

    public func setEnabled(_ enabled: Bool) throws {
        try queue.sync {
            if enabled {
                try enable()
            } else {
                disable()
            }
        }
    }

    private func enable() throws {
        guard displayAssertionID == 0 else { return }

        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionName,
            &displayAssertionID
        )
        guard displayResult == kIOReturnSuccess else {
            displayAssertionID = 0
            throw AutomaticLockControllerError.displayAssertionFailed(displayResult)
        }

        do {
            try declareUserActivity()
        } catch {
            disable()
            throw error
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            do {
                try self.declareUserActivity()
            } catch {
                self.disable()
                self.logger.error("User activity refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        timer.resume()
        self.timer = timer
    }

    private func disable() {
        timer?.cancel()
        timer = nil

        if activityAssertionID != 0 {
            IOPMAssertionRelease(activityAssertionID)
            activityAssertionID = 0
        }
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    private func declareUserActivity() throws {
        let result = IOPMAssertionDeclareUserActivity(
            assertionName,
            kIOPMUserActiveLocal,
            &activityAssertionID
        )
        guard result == kIOReturnSuccess else {
            throw AutomaticLockControllerError.userActivityFailed(result)
        }
    }
}
