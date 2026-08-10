import LidGuardCore
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: AppStore
    @State private var isEditingProtection = false
    @State private var isConfiguringRun = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusHeader
            modeSwitcher
            Divider()
            metrics

            if store.status?.mode == .active {
                activeSession
                Button {
                    if !isEditingProtection {
                        store.prepareCurrentSessionForEditing()
                    }
                    isEditingProtection.toggle()
                } label: {
                    HStack {
                        Label("调整保护策略", systemImage: "slider.horizontal.3")
                        Spacer()
                        Image(systemName: isEditingProtection ? "chevron.up" : "chevron.down")
                    }
                }
                .buttonStyle(.bordered)

                if isEditingProtection {
                    sessionControls(
                        sectionTitle: "当前合盖运行设置",
                        guidance: "修改后会立即应用到当前会话。",
                        actionTitle: "应用保护策略"
                    ) {
                        store.applySelectedSession()
                    }
                }
            } else {
                normalSleepSummary

                Button {
                    isConfiguringRun.toggle()
                } label: {
                    HStack {
                        Label(
                            isConfiguringRun ? "收起合盖运行设置" : "配置并开启合盖运行",
                            systemImage: "laptopcomputer.and.arrow.down"
                        )
                        Spacer()
                        Image(systemName: isConfiguringRun ? "chevron.up" : "chevron.down")
                    }
                }
                .buttonStyle(.borderedProminent)

                if isConfiguringRun {
                    sessionControls(
                        sectionTitle: "合盖运行设置",
                        guidance: "选择保护策略和运行时长，确认后才会开启合盖运行。",
                        actionTitle: "开始合盖运行"
                    ) {
                        store.startSelectedSession()
                    }
                }
            }

            if let error = store.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.helperRepairRequired {
                Button {
                    store.repairHelper()
                } label: {
                    Label(store.helperRepairActionTitle, systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isWorking)
            }

            Divider()
            HStack {
                Button("设置") { SettingsWindowController.shared.show(store: store) }
                Spacer()
                Button("刷新") { Task { await store.refresh() } }
                Button("退出") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(16)
        .frame(width: 360)
        .alert("确认完全手动不限时运行？", isPresented: $store.manualRiskConfirmationPending) {
            Button("取消", role: .cancel) {}
            Button("确认开启", role: .destructive) { store.confirmManualUnlimited() }
        } message: {
            Text("密闭保护套或包内运行可能积热。严重热状态只警告，临界热状态仍会强制恢复休眠。")
        }
    }

    private var modeSwitcher: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("运行模式")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                modeButton(
                    title: "合盖运行",
                    subtitle: "持续远控",
                    icon: "laptopcomputer.and.arrow.down",
                    selected: store.status?.mode == .active,
                    tint: .green
                ) {
                    guard store.status?.mode != .active else { return }
                    isConfiguringRun = true
                }
                modeButton(
                    title: "正常休眠",
                    subtitle: "恢复系统默认",
                    icon: "moon.zzz",
                    selected: store.status?.mode == .normal,
                    tint: .blue
                ) {
                    guard store.status?.mode != .normal else { return }
                    isConfiguringRun = false
                    store.stopSession()
                }
            }
        }
    }

    private func modeButton(
        title: String,
        subtitle: String,
        icon: String,
        selected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tint)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(selected ? tint.opacity(0.12) : Color.secondary.opacity(0.07))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? tint.opacity(0.65) : Color.clear, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(
            store.isWorking
                || store.helperRepairRequired
                || store.status == nil
                || store.status?.mode == .error
        )
    }

    private var statusHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metric(
                title: "热状态",
                value: store.status?.thermalLevel.displayName ?? "未知",
                icon: "thermometer.medium"
            )
            metric(
                title: "电量",
                value: batteryText,
                icon: "battery.75percent"
            )
            metric(
                title: "供电",
                value: store.status?.battery.source.displayName ?? "未知",
                icon: "powerplug"
            )
        }
    }

    private var normalSleepSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("由 macOS 正常管理睡眠", systemImage: "checkmark.shield")
                .font(.subheadline.weight(.semibold))
            Text("当前没有合盖运行会话，也没有时长、低电量或温度保护倒计时。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func sessionControls(
        sectionTitle: String,
        guidance: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sectionTitle).font(.subheadline.weight(.semibold))
                Text(guidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("运行策略", selection: $store.selectedProfile) {
                ForEach(RunProfile.allCases, id: \.self) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: store.selectedProfile) { _ in
                store.normalizeSelectionForProfile()
            }

            Picker("合盖运行时长", selection: $store.durationChoice) {
                ForEach(store.availableDurations) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }

            if store.durationChoice == .custom {
                DatePicker(
                    "自动恢复时间",
                    selection: $store.customDeadline,
                    in: store.customDeadlineRange
                )
            }

            Text(durationExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            batteryProtectionControls

            Text(profileDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isWorking || store.helperRepairRequired || store.status == nil)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var batteryProtectionControls: some View {
        switch store.selectedProfile {
        case .strict:
            LabeledContent("低电量保护", value: "固定 30%")
        case .balanced:
            batteryThresholdStepper
        case .manual:
            Toggle("启用低电量保护", isOn: $store.manualBatteryProtection)
            if store.manualBatteryProtection {
                batteryThresholdStepper
            }
        }
    }

    private var batteryThresholdStepper: some View {
        Stepper(
            "低电量阈值：\(store.balancedBatteryThreshold)%",
            value: $store.balancedBatteryThreshold,
            in: LidGuardConstants.minimumBatteryThreshold...LidGuardConstants.maximumBatteryThreshold,
            step: 5
        )
    }

    private var durationExplanation: String {
        if store.durationChoice == .unlimited {
            return "将持续合盖运行，直到你手动恢复正常休眠。"
        }
        return "到期后自动恢复正常合盖休眠；如果当时仍合盖，vivo 和 Agent 会随系统睡眠断开。"
    }

    private var activeSession: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let session = store.status?.session {
                Label(session.profile.displayName, systemImage: "shield.checkered")
                    .font(.subheadline.weight(.semibold))
                Text(session.deadline.map(deadlineText) ?? "不限时运行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("低电量保护：\(session.batteryThreshold.map { "\($0)%" } ?? "关闭")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusTitle: String {
        switch store.status?.mode {
        case .active: return "合盖运行中"
        case .normal: return "正常合盖休眠"
        case .externalEnabled: return "外部合盖运行状态"
        case .error, .none: return "Helper 未连接"
        }
    }

    private var statusSubtitle: String {
        if let event = store.status?.lastEvent { return event.message }
        return "只切换合盖休眠，不接管显示器"
    }

    private var statusIcon: String {
        store.status?.mode == .active ? "laptopcomputer.and.arrow.down" : "moon.zzz"
    }

    private var statusColor: Color {
        store.status?.mode == .active ? .green : .secondary
    }

    private var batteryText: String {
        store.status?.battery.percentage.map { "\($0)%" } ?? "未知"
    }

    private var profileDescription: String {
        switch store.selectedProfile {
        case .strict: return "最长 8 小时，30% 低电量保护，严重热状态自动恢复。"
        case .balanced: return "低电量阈值可调，严重热状态自动恢复，可选择不限时。"
        case .manual: return "严重热状态只警告，临界热状态强制恢复；低电量保护默认关闭。"
        }
    }

    private func deadlineText(_ deadline: Date) -> String {
        "将在 \(deadline.formatted(date: .omitted, time: .shortened)) 自动恢复"
    }

}

struct SettingsContentView: View {
    @ObservedObject var store: AppStore
    @State private var confirmUninstall = false

    var body: some View {
        Form {
            Section("常规") {
                Toggle(
                    "登录时启动合盖守护",
                    isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.setLaunchAtLogin($0) }
                    )
                )
                Stepper(
                    "默认低电量阈值：\(store.balancedBatteryThreshold)%",
                    value: $store.balancedBatteryThreshold,
                    in: LidGuardConstants.minimumBatteryThreshold...LidGuardConstants.maximumBatteryThreshold,
                    step: 5
                )
            }

            Section("组件") {
                LabeledContent("Helper", value: store.helperAuthorizationDisplayName)
                LabeledContent("CLI", value: FileManager.default.fileExists(atPath: LidGuardConstants.cliPath) ? "已安装" : "未安装")
                Button(store.helperRepairActionTitle) { store.repairHelper() }
                    .disabled(store.isWorking)
                Button("恢复休眠并卸载 Helper", role: .destructive) { confirmUninstall = true }
            }

            Section("诊断") {
                LabeledContent("协议版本", value: "\(store.status?.protocolVersion ?? 0)")
                LabeledContent("Helper 版本", value: store.status?.helperVersion ?? "未连接")
                LabeledContent("SleepDisabled", value: store.status?.sleepDisabled.map { $0 ? "1" : "0" } ?? "未知")
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480, height: 390)
        .alert("确认卸载 Helper？", isPresented: $confirmUninstall) {
            Button("取消", role: .cancel) {}
            Button("恢复并卸载", role: .destructive) { store.uninstallHelper() }
        } message: {
            Text("将先恢复正常合盖休眠，再删除 LaunchDaemon、Helper 和 CLI。App 与源码会保留。")
        }
    }
}
