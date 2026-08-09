import Foundation
import LidGuardCore
import SwiftUI

enum DurationChoice: String, CaseIterable, Identifiable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case eightHours
    case twelveHours
    case oneDay
    case custom
    case unlimited

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thirtyMinutes: return "30 分钟"
        case .oneHour: return "1 小时"
        case .twoHours: return "2 小时"
        case .fourHours: return "4 小时"
        case .eightHours: return "8 小时"
        case .twelveHours: return "12 小时"
        case .oneDay: return "24 小时"
        case .custom: return "自定义结束时间"
        case .unlimited: return "不限时"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .eightHours: return 8 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        case .oneDay: return 24 * 60 * 60
        case .custom, .unlimited: return nil
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var status: StatusSnapshot?
    @Published var errorMessage: String?
    @Published var selectedProfile: RunProfile = .balanced
    @Published var durationChoice: DurationChoice = .twoHours
    @Published var customDeadline = Date().addingTimeInterval(2 * 60 * 60)
    @Published var manualBatteryProtection = false
    @Published var manualRiskConfirmationPending = false
    @Published var isWorking = false
    @Published private(set) var helperAuthorizationStatus = InstallerManager.helperAuthorizationStatus
    @AppStorage("balancedBatteryThreshold") var balancedBatteryThreshold = 20
    @AppStorage("launchAtLogin") var launchAtLogin = true

    private var pollingTask: Task<Void, Never>?
    private var manualRiskConfirmed = false
    private let lastEventKey = "lastNotifiedEventID"

    var availableDurations: [DurationChoice] {
        if selectedProfile == .strict {
            return [.thirtyMinutes, .oneHour, .twoHours, .fourHours, .eightHours, .custom]
        }
        return DurationChoice.allCases
    }

    var customDeadlineRange: ClosedRange<Date> {
        let now = Date()
        if selectedProfile == .strict {
            return now.addingTimeInterval(30 * 60)...now.addingTimeInterval(8 * 60 * 60)
        }
        return now.addingTimeInterval(60)...now.addingTimeInterval(7 * 24 * 60 * 60)
    }

    var helperRepairRequired: Bool {
        helperAuthorizationStatus == .missing || helperAuthorizationStatus == .outdated
    }

    var helperRepairActionTitle: String {
        switch helperAuthorizationStatus {
        case .missing: return "安装 Helper"
        case .outdated: return "重新授权 Helper"
        case .current, .unknown: return "修复 Helper 与 CLI"
        }
    }

    var helperAuthorizationDisplayName: String {
        switch helperAuthorizationStatus {
        case .current: return "可用"
        case .missing: return "未安装"
        case .outdated: return "需重新授权"
        case .unknown: return "状态未知"
        }
    }

    init() {
        NotificationManager.shared.requestAuthorization()
        if launchAtLogin {
            try? LaunchAtLoginManager.enable()
        }
        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func refresh() async {
        if helperAuthorizationStatus != .current {
            helperAuthorizationStatus = InstallerManager.helperAuthorizationStatus
            if let message = helperAuthorizationMessage {
                status = nil
                errorMessage = message
                return
            }
        }
        do {
            let snapshot = try await Task.detached {
                try HelperClient().fetchStatus()
            }.value
            status = snapshot
            errorMessage = snapshot.lastError
            helperAuthorizationStatus = .current
            processEvent(snapshot.lastEvent)
        } catch {
            helperAuthorizationStatus = InstallerManager.helperAuthorizationStatus
            errorMessage = helperAuthorizationMessage ?? error.localizedDescription
        }
    }

    func startSelectedSession() {
        submitSelectedSession()
    }

    func applySelectedSession() {
        submitSelectedSession()
    }

    func prepareCurrentSessionForEditing() {
        guard let session = status?.session else { return }
        selectedProfile = session.profile
        if let deadline = session.deadline {
            durationChoice = .custom
            let range = customDeadlineRange
            customDeadline = min(max(deadline, range.lowerBound), range.upperBound)
        } else {
            durationChoice = .unlimited
        }
        manualBatteryProtection = session.batteryThreshold != nil
        if session.profile != .strict, let threshold = session.batteryThreshold {
            balancedBatteryThreshold = threshold
        }
    }

    func normalizeSelectionForProfile() {
        if !availableDurations.contains(durationChoice) {
            durationChoice = .twoHours
        }
        guard durationChoice == .custom else { return }
        let range = customDeadlineRange
        customDeadline = min(max(customDeadline, range.lowerBound), range.upperBound)
    }

    private func submitSelectedSession() {
        if selectedProfile == .manual,
           durationChoice == .unlimited,
           !manualRiskConfirmed {
            manualRiskConfirmationPending = true
            return
        }
        let threshold: Int?
        switch selectedProfile {
        case .strict: threshold = LidGuardConstants.strictBatteryThreshold
        case .balanced: threshold = balancedBatteryThreshold
        case .manual: threshold = manualBatteryProtection ? balancedBatteryThreshold : nil
        }
        let request = SessionRequest(
            profile: selectedProfile,
            deadline: makeDeadline(),
            batteryThreshold: threshold,
            confirmedManualUnlimitedRisk: manualRiskConfirmed
        )
        let shouldUpdate = status?.mode == .active && status?.session?.profile == selectedProfile
        manualRiskConfirmed = false
        if shouldUpdate {
            let update = UpdateSessionRequest(
                deadline: request.deadline,
                batteryThreshold: request.batteryThreshold,
                confirmedManualUnlimitedRisk: request.confirmedManualUnlimitedRisk
            )
            perform { client in
                try client.update(update)
            }
        } else {
            perform { client in
                try client.start(request)
            }
        }
    }

    func confirmManualUnlimited() {
        manualRiskConfirmationPending = false
        manualRiskConfirmed = true
        startSelectedSession()
    }

    func stopSession() {
        perform { client in try client.stop() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        do {
            if enabled {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func repairHelper() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            do {
                try await Task.detached {
                    try InstallerManager.repairHelper()
                }.value
                helperAuthorizationStatus = InstallerManager.helperAuthorizationStatus
                errorMessage = nil
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func uninstallHelper() {
        do {
            try? LaunchAtLoginManager.disable()
            try InstallerManager.uninstallHelper()
            status = nil
            helperAuthorizationStatus = .missing
            Task { await refresh() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeDeadline() -> Date? {
        if durationChoice == .unlimited { return nil }
        if durationChoice == .custom { return customDeadline }
        return durationChoice.interval.map { Date().addingTimeInterval($0) }
    }

    private func perform(_ operation: @escaping (HelperClient) throws -> OperationResult) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            do {
                let result = try await Task.detached {
                    try operation(HelperClient())
                }.value
                status = result.status
                errorMessage = result.status.lastError
                processEvent(result.status.lastEvent)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func processEvent(_ event: GuardEvent?) {
        guard let event else { return }
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastEventKey) != event.id.uuidString else { return }
        defaults.set(event.id.uuidString, forKey: lastEventKey)
        NotificationManager.shared.notify(
            title: "合盖守护",
            body: event.message,
            identifier: event.id.uuidString
        )
    }

    private var helperAuthorizationMessage: String? {
        switch helperAuthorizationStatus {
        case .current, .unknown:
            return nil
        case .missing:
            return "Helper 未安装，请先安装 Helper 与 CLI。"
        case .outdated:
            return "App 已更新，需要重新授权 Helper 后才能通信。"
        }
    }
}
