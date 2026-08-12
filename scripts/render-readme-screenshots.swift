import AppKit
import SwiftUI

private enum Palette {
    static let darkBackground = Color(red: 0.115, green: 0.12, blue: 0.15)
    static let darkCard = Color.white.opacity(0.075)
    static let lightBackground = Color(red: 0.945, green: 0.945, blue: 0.945)
    static let lightCard = Color.black.opacity(0.045)
    static let green = Color(red: 0.11, green: 0.82, blue: 0.30)
    static let blue = Color(red: 0.0, green: 0.48, blue: 1.0)
}

private struct Copy {
    let activeTitle: String
    let activeSubtitle: String
    let normalTitle: String
    let normalSubtitle: String
    let runMode: String
    let keepRunning: String
    let keepRunningSubtitle: String
    let normalSleep: String
    let normalSleepSubtitle: String
    let thermal: String
    let thermalNormal: String
    let battery: String
    let power: String
    let acPower: String
    let balanced: String
    let noTimeLimit: String
    let lowBatteryThreshold: String
    let preventAutomaticLock: String
    let automaticLockActive: String
    let adjustSafeguards: String
    let settings: String
    let refresh: String
    let quit: String
    let currentSafeguards: String
    let changesImmediately: String
    let strict: String
    let manual: String
    let duration: String
    let unlimitedHint: String
    let thresholdHint: String
    let applyChanges: String
    let normalBehavior: String
    let noActiveSession: String
    let setUpMode: String

    static let english = Copy(
        activeTitle: "Running with Lid Closed",
        activeSubtitle: "Balanced safeguards are active",
        normalTitle: "Normal Lid Sleep",
        normalSubtitle: "macOS will sleep when the lid closes",
        runMode: "RUN MODE",
        keepRunning: "Keep Running",
        keepRunningSubtitle: "Work stays active",
        normalSleep: "Normal Sleep",
        normalSleepSubtitle: "Sleeps on close",
        thermal: "THERMAL",
        thermalNormal: "Normal",
        battery: "BATTERY",
        power: "POWER",
        acPower: "AC Power",
        balanced: "Balanced",
        noTimeLimit: "No time limit",
        lowBatteryThreshold: "Low-battery threshold",
        preventAutomaticLock: "Prevent automatic lock",
        automaticLockActive: "Display and user-activity protection active",
        adjustSafeguards: "Adjust Safeguards",
        settings: "Settings",
        refresh: "Refresh",
        quit: "Quit",
        currentSafeguards: "CURRENT SESSION SAFEGUARDS",
        changesImmediately: "Changes take effect immediately.",
        strict: "Strict",
        manual: "Manual",
        duration: "Duration",
        unlimitedHint: "Keeps running until you restore normal lid sleep.",
        thresholdHint: "Adjustable threshold. Serious thermal pressure automatically restores normal sleep.",
        applyChanges: "Apply Changes",
        normalBehavior: "Normal macOS sleep behavior",
        noActiveSession: "No LidGuard session or safeguards are active.",
        setUpMode: "Set Up Lid-Closed Mode"
    )

    static let chinese = Copy(
        activeTitle: "合盖运行中",
        activeSubtitle: "已开启平衡模式的合盖运行",
        normalTitle: "正常合盖休眠",
        normalSubtitle: "合盖后由 macOS 正常进入休眠",
        runMode: "运行模式",
        keepRunning: "合盖运行",
        keepRunningSubtitle: "持续远控",
        normalSleep: "正常休眠",
        normalSleepSubtitle: "恢复系统默认",
        thermal: "热状态",
        thermalNormal: "正常",
        battery: "电量",
        power: "供电",
        acPower: "电源",
        balanced: "平衡",
        noTimeLimit: "不限时运行",
        lowBatteryThreshold: "低电量保护",
        preventAutomaticLock: "防止自动锁屏",
        automaticLockActive: "显示器与用户活跃保护已生效",
        adjustSafeguards: "调整保护策略",
        settings: "设置",
        refresh: "刷新",
        quit: "退出",
        currentSafeguards: "当前会话保护策略",
        changesImmediately: "修改后立即生效。",
        strict: "严格",
        manual: "完全手动",
        duration: "运行时长",
        unlimitedHint: "持续运行，直到手动恢复正常休眠。",
        thresholdHint: "可调整阈值；系统热压力严重时自动恢复正常休眠。",
        applyChanges: "应用修改",
        normalBehavior: "正常 macOS 合盖休眠",
        noActiveSession: "当前没有 LidGuard 会话或保护策略。",
        setUpMode: "设置合盖运行"
    )
}

private struct MenuBar: View {
    let active: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 12, weight: .semibold))
            Text("Finder")
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            HStack(spacing: 11) {
                Image(systemName: "laptopcomputer.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? Palette.green : .white)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
                Text("10:08")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color.black.opacity(0.88))
    }
}

private struct MenuBarScene<Content: View>: View {
    let active: Bool
    let content: Content

    init(active: Bool, @ViewBuilder content: () -> Content) {
        self.active = active
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            MenuBar(active: active)
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.11, blue: 0.15),
                        Color(red: 0.055, green: 0.07, blue: 0.1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                content
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 0.75)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
                    .padding(.top, 8)
                    .padding(.trailing, 10)
                    .padding(.bottom, 22)
            }
        }
        .frame(width: 400)
    }
}

private struct Header: View {
    let active: Bool
    let copy: Copy

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: active ? "laptopcomputer.and.arrow.down" : "moon.zzz")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(active ? Palette.green : .secondary)
                .frame(width: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(active ? copy.activeTitle : copy.normalTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(active ? copy.activeSubtitle : copy.normalSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let selected: Bool
    let tint: Color
    let dark: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 2)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(selected ? tint.opacity(dark ? 0.15 : 0.12) : (dark ? Palette.darkCard : Palette.lightCard))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? tint.opacity(0.75) : .clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ModeSwitcher: View {
    let active: Bool
    let dark: Bool
    let copy: Copy

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(copy.runMode)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ModeCard(
                    title: copy.keepRunning,
                    subtitle: copy.keepRunningSubtitle,
                    icon: "laptopcomputer.and.arrow.down",
                    selected: active,
                    tint: Palette.green,
                    dark: dark
                )
                ModeCard(
                    title: copy.normalSleep,
                    subtitle: copy.normalSleepSubtitle,
                    icon: "moon.zzz",
                    selected: !active,
                    tint: Palette.blue,
                    dark: dark
                )
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Metrics: View {
    let battery: Int
    let dark: Bool
    let copy: Copy

    var body: some View {
        HStack(spacing: 10) {
            MetricCard(title: copy.thermal, value: copy.thermalNormal, icon: "thermometer.medium", dark: dark)
            MetricCard(title: copy.battery, value: "\(battery)%", icon: "battery.75percent", dark: dark)
            MetricCard(title: copy.power, value: copy.acPower, icon: "powerplug", dark: dark)
        }
    }
}

private struct ActiveSession: View {
    let threshold: Int
    let dark: Bool
    let copy: Copy

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(copy.balanced, systemImage: "shield.checkered")
                .font(.subheadline.weight(.semibold))
            Text(copy.noTimeLimit)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(copy.lowBatteryThreshold): \(threshold)%")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(copy.preventAutomaticLock, systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.green)
            Text(copy.automaticLockActive)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.green.opacity(dark ? 0.11 : 0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Footer: View {
    let copy: Copy

    var body: some View {
        HStack {
            Text(copy.settings)
            Spacer()
            Text(copy.refresh)
            Text(copy.quit)
        }
        .font(.caption)
        .fontWeight(.medium)
    }
}

private struct ActivePanel: View {
    let expanded: Bool
    let dark: Bool
    let threshold: Int
    let copy: Copy

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Header(active: true, copy: copy)
            ModeSwitcher(active: true, dark: dark, copy: copy)
            Divider()
            Metrics(battery: 86, dark: dark, copy: copy)
            ActiveSession(threshold: threshold, dark: dark, copy: copy)

            HStack {
                Label(copy.adjustSafeguards, systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 8))

            if expanded {
                ExpandedControls(threshold: threshold, dark: dark, copy: copy)
            }

            Divider()
            Footer(copy: copy)
        }
        .padding(16)
        .frame(width: 360, height: expanded ? 683.5 : 439.5, alignment: .topLeading)
        .background(dark ? Palette.darkBackground : Palette.lightBackground)
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}

private struct ExpandedControls: View {
    let threshold: Int
    let dark: Bool
    let copy: Copy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(copy.currentSafeguards)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(copy.changesImmediately)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                Segment(copy.strict, selected: false, dark: dark)
                Segment(copy.balanced, selected: true, dark: dark)
                Segment(copy.manual, selected: false, dark: dark)
            }
            .frame(height: 28)
            .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 7))

            HStack {
                Text(copy.duration)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(copy.noTimeLimit)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 7))

            Text(copy.unlimitedHint)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            HStack {
                Text(copy.lowBatteryThreshold)
                    .font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text("\(threshold)%")
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 0) {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 30)
                    Divider().frame(height: 22)
                    Image(systemName: "plus")
                        .frame(width: 28, height: 30)
                }
                .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 7))
            }

            Text(copy.thresholdHint)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.applyChanges)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(Palette.blue, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)
        }
    }
}

private struct Segment: View {
    let title: String
    let selected: Bool
    let dark: Bool

    init(_ title: String, selected: Bool, dark: Bool) {
        self.title = title
        self.selected = selected
        self.dark = dark
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? Color.secondary.opacity(dark ? 0.45 : 0.3) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct NormalPanel: View {
    let copy: Copy

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header(active: false, copy: copy)
            ModeSwitcher(active: false, dark: false, copy: copy)
            Divider()
            Metrics(battery: 86, dark: false, copy: copy)

            VStack(alignment: .leading, spacing: 5) {
                Label(copy.normalBehavior, systemImage: "checkmark.shield")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(copy.noActiveSession)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Label(copy.setUpMode, systemImage: "laptopcomputer.and.arrow.down")
                    .font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Palette.blue, in: RoundedRectangle(cornerRadius: 8))

            Divider()
            Footer(copy: copy)
        }
        .padding(16)
        .frame(width: 360, height: 379.5, alignment: .topLeading)
        .background(Palette.lightBackground)
        .environment(\.colorScheme, .light)
    }
}

@MainActor
private func render<V: View>(_ view: V, to path: String) throws {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: URL(fileURLWithPath: path), options: .atomic)
}

@main
struct ReadmeScreenshotRenderer {
    @MainActor
    static func main() throws {
        let root = FileManager.default.currentDirectoryPath
        let assets = URL(fileURLWithPath: root).appendingPathComponent("docs/assets").path
        try FileManager.default.createDirectory(atPath: assets, withIntermediateDirectories: true)
        try render(
            MenuBarScene(active: true) {
                ActivePanel(expanded: true, dark: true, threshold: 35, copy: .english)
            },
            to: "\(assets)/lidguard-expanded-en.png"
        )
        try render(
            MenuBarScene(active: true) {
                ActivePanel(expanded: false, dark: false, threshold: 20, copy: .english)
            },
            to: "\(assets)/lidguard-active-en.png"
        )
        try render(
            MenuBarScene(active: false) {
                NormalPanel(copy: .english)
            },
            to: "\(assets)/lidguard-normal-en.png"
        )
        try render(
            MenuBarScene(active: true) {
                ActivePanel(expanded: true, dark: true, threshold: 35, copy: .chinese)
            },
            to: "\(assets)/lidguard-expanded.png"
        )
        try render(
            MenuBarScene(active: true) {
                ActivePanel(expanded: false, dark: false, threshold: 20, copy: .chinese)
            },
            to: "\(assets)/lidguard-active.png"
        )
        try render(
            MenuBarScene(active: false) {
                NormalPanel(copy: .chinese)
            },
            to: "\(assets)/lidguard-normal.png"
        )
    }
}
