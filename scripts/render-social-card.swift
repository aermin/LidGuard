import AppKit
import SwiftUI

private struct FeaturePill: View {
    let icon: String
    let title: String
    var highlighted = false

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(highlighted ? Color(red: 0.25, green: 1.0, blue: 0.5) : Color.white.opacity(0.82))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                highlighted ? Color(red: 0.08, green: 0.82, blue: 0.30).opacity(0.14) : Color.white.opacity(0.08),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    highlighted ? Color(red: 0.12, green: 0.9, blue: 0.36).opacity(0.45) : Color.white.opacity(0.12),
                    lineWidth: 1
                )
            }
    }
}

private struct SocialCardCopy {
    let headline: String
    let detail: String
    let timedRecovery: String
    let preventAutomaticLock: String
    let lowBattery: String
    let thermalSafeguards: String
    let footer: String

    static let english = SocialCardCopy(
        headline: "Close the lid.\nKeep the work running.",
        detail: "Run agents, remote access, builds, and downloads\nwith optional automatic-lock prevention.",
        timedRecovery: "Timed recovery",
        preventAutomaticLock: "Prevent auto-lock",
        lowBattery: "Low battery",
        thermalSafeguards: "Thermal safeguards",
        footer: "macOS 13+  ·  Apple Silicon  ·  Public preview"
    )

    static let chinese = SocialCardCopy(
        headline: "放心合盖。\n任务继续运行。",
        detail: "Agent、手机远控、构建和下载不中断，\n并可按需防止自动锁屏。",
        timedRecovery: "定时恢复",
        preventAutomaticLock: "防止自动锁屏",
        lowBattery: "低电量保护",
        thermalSafeguards: "热状态保护",
        footer: "macOS 13+  ·  Apple Silicon  ·  Public preview"
    )
}

private struct SocialCard: View {
    let screenshot: NSImage
    let copy: SocialCardCopy

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.055, blue: 0.075),
                    Color(red: 0.055, green: 0.075, blue: 0.105),
                    Color(red: 0.025, green: 0.035, blue: 0.055),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.08, green: 0.88, blue: 0.38).opacity(0.13))
                .frame(width: 460, height: 460)
                .blur(radius: 90)
                .offset(x: 320, y: -180)

            HStack(spacing: 58) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: "laptopcomputer.and.arrow.down")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color(red: 0.1, green: 0.9, blue: 0.38))
                        Text("LidGuard")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer().frame(height: 52)

                    Text(copy.headline)
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .tracking(-1.2)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 24)

                    Text(copy.detail)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 32)

                    HStack(spacing: 10) {
                        FeaturePill(icon: "timer", title: copy.timedRecovery)
                        FeaturePill(
                            icon: "lock.open",
                            title: copy.preventAutomaticLock,
                            highlighted: true
                        )
                    }
                    Spacer().frame(height: 10)
                    HStack(spacing: 10) {
                        FeaturePill(icon: "battery.25percent", title: copy.lowBattery)
                        FeaturePill(icon: "thermometer.high", title: copy.thermalSafeguards)
                    }

                    Spacer()

                    Text(copy.footer)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
                .frame(width: 455, alignment: .leading)

                Image(nsImage: screenshot)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 248)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 28, x: 0, y: 18)
                    .rotationEffect(.degrees(1.3))
            }
            .padding(.horizontal, 58)
            .padding(.vertical, 46)
        }
        .frame(width: 800, height: 450)
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
struct SocialCardRenderer {
    @MainActor
    static func main() throws {
        let root = FileManager.default.currentDirectoryPath
        let englishSource = "\(root)/docs/assets/lidguard-expanded-en.png"
        let chineseSource = "\(root)/docs/assets/lidguard-expanded.png"
        guard let englishScreenshot = NSImage(contentsOfFile: englishSource),
              let chineseScreenshot = NSImage(contentsOfFile: chineseSource) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try render(
            SocialCard(screenshot: englishScreenshot, copy: .english),
            to: "\(root)/docs/assets/lidguard-social-card.png"
        )
        try render(
            SocialCard(screenshot: chineseScreenshot, copy: .chinese),
            to: "\(root)/docs/assets/lidguard-social-card-zh.png"
        )
    }
}
