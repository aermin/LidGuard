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

private struct Header: View {
    let active: Bool
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: active ? "laptopcomputer.and.arrow.down" : "moon.zzz")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(active ? Palette.green : .secondary)
                .frame(width: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(active ? "Running with Lid Closed" : "Normal Lid Sleep")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("RUN MODE")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ModeCard(
                    title: "Keep Running",
                    subtitle: "Remote access on",
                    icon: "laptopcomputer.and.arrow.down",
                    selected: active,
                    tint: Palette.green,
                    dark: dark
                )
                ModeCard(
                    title: "Normal Sleep",
                    subtitle: "macOS default",
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

    var body: some View {
        HStack(spacing: 10) {
            MetricCard(title: "THERMAL", value: "Normal", icon: "thermometer.medium", dark: dark)
            MetricCard(title: "BATTERY", value: "\(battery)%", icon: "battery.75percent", dark: dark)
            MetricCard(title: "POWER", value: "Adapter", icon: "powerplug", dark: dark)
        }
    }
}

private struct ActiveSession: View {
    let threshold: Int
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Balanced", systemImage: "shield.checkered")
                .font(.subheadline.weight(.semibold))
            Text("Unlimited session")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Low-battery protection: \(threshold)%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.green.opacity(dark ? 0.11 : 0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Footer: View {
    var body: some View {
        HStack {
            Text("Settings")
            Spacer()
            Text("Refresh")
            Text("Quit")
        }
        .font(.caption)
        .fontWeight(.medium)
    }
}

private struct ActivePanel: View {
    let expanded: Bool
    let dark: Bool
    let threshold: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Header(active: true, subtitle: "Balanced lid-closed session is active")
            ModeSwitcher(active: true, dark: dark)
            Divider()
            Metrics(battery: 86, dark: dark)
            ActiveSession(threshold: threshold, dark: dark)

            HStack {
                Label("Adjust Safeguards", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 8))

            if expanded {
                ExpandedControls(threshold: threshold, dark: dark)
            }

            Divider()
            Footer()
        }
        .padding(16)
        .frame(width: 360, height: expanded ? 639.5 : 395.5, alignment: .topLeading)
        .background(dark ? Palette.darkBackground : Palette.lightBackground)
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}

private struct ExpandedControls: View {
    let threshold: Int
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CURRENT SESSION SAFEGUARDS")
                    .font(.system(size: 11.5, weight: .semibold))
                Text("Changes apply immediately to the current session.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                Segment("Strict", selected: false, dark: dark)
                Segment("Balanced", selected: true, dark: dark)
                Segment("Manual", selected: false, dark: dark)
            }
            .frame(height: 28)
            .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 7))

            HStack {
                Text("Session duration")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("Unlimited")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(dark ? Palette.darkCard : Palette.lightCard, in: RoundedRectangle(cornerRadius: 7))

            Text("Keeps running until you manually restore normal lid sleep.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            HStack {
                Text("Low-battery threshold")
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

            Text("Threshold is adjustable. Serious heat restores sleep automatically; unlimited sessions are optional.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Apply Safeguards")
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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header(active: false, subtitle: "Default macOS lid sleep is restored")
            ModeSwitcher(active: false, dark: false)
            Divider()
            Metrics(battery: 86, dark: false)

            VStack(alignment: .leading, spacing: 5) {
                Label("Sleep is managed normally by macOS", systemImage: "checkmark.shield")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("No lid-closed session or timer, battery, or thermal safeguard is active.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Label("Configure Lid-Closed Session", systemImage: "laptopcomputer.and.arrow.down")
                    .font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Palette.blue, in: RoundedRectangle(cornerRadius: 8))

            Divider()
            Footer()
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
            ActivePanel(expanded: true, dark: true, threshold: 35),
            to: "\(assets)/lidguard-expanded-en.png"
        )
        try render(
            ActivePanel(expanded: false, dark: false, threshold: 20),
            to: "\(assets)/lidguard-active-en.png"
        )
        try render(
            NormalPanel(),
            to: "\(assets)/lidguard-normal-en.png"
        )
    }
}
