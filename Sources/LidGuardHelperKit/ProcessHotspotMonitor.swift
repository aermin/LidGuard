import Darwin
import Foundation
import LidGuardCore
import os

public struct ProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var uid: UInt32
    public var cpuPercent: Double
    public var startIdentity: String
    public var command: String

    public init(
        pid: Int32,
        uid: UInt32,
        cpuPercent: Double,
        startIdentity: String,
        command: String
    ) {
        self.pid = pid
        self.uid = uid
        self.cpuPercent = cpuPercent
        self.startIdentity = startIdentity
        self.command = command
    }

    var displayName: String {
        URL(fileURLWithPath: command).lastPathComponent
    }
}

public protocol ProcessHotspotMonitoring: AnyObject {
    func evaluate(thermalLevel: ThermalLevel, enabled: Bool, now: Date) -> ProcessHotspot?
}

public final class NoopProcessHotspotMonitor: ProcessHotspotMonitoring {
    public init() {}

    public func evaluate(thermalLevel: ThermalLevel, enabled: Bool, now: Date) -> ProcessHotspot? {
        nil
    }
}

public final class HotspotDetector {
    private struct ProcessIdentity: Hashable {
        var pid: Int32
        var startIdentity: String
    }

    private var firstSeenAt: [ProcessIdentity: Date] = [:]

    public init() {}

    public func reset() {
        firstSeenAt.removeAll()
    }

    public func candidate(
        from samples: [ProcessSample],
        ownerUID: UInt32,
        thermalLevel: ThermalLevel,
        now: Date
    ) -> ProcessSample? {
        guard let policy = Self.policy(for: thermalLevel) else {
            reset()
            return nil
        }

        let eligible = samples.filter { sample in
            Self.isAllowedOwner(sample, ownerUID: ownerUID)
                && sample.pid > 1
                && sample.cpuPercent >= policy.cpuThreshold
                && !Self.isProtected(sample)
        }
        let identities = Set(eligible.map { ProcessIdentity(pid: $0.pid, startIdentity: $0.startIdentity) })
        firstSeenAt = firstSeenAt.filter { identities.contains($0.key) }

        for sample in eligible {
            let identity = ProcessIdentity(pid: sample.pid, startIdentity: sample.startIdentity)
            if firstSeenAt[identity] == nil {
                firstSeenAt[identity] = now
            }
        }

        let confirmed = eligible.filter { sample in
            let identity = ProcessIdentity(pid: sample.pid, startIdentity: sample.startIdentity)
            guard let firstSeen = firstSeenAt[identity] else { return false }
            return now.timeIntervalSince(firstSeen) >= policy.requiredDuration
        }
        return confirmed.max { $0.cpuPercent < $1.cpuPercent }
    }

    public static func policy(for thermalLevel: ThermalLevel) -> (cpuThreshold: Double, requiredDuration: TimeInterval)? {
        switch thermalLevel {
        case .fair:
            return (
                LidGuardConstants.hotspotFairCPUThreshold,
                LidGuardConstants.hotspotFairDuration
            )
        case .serious:
            return (
                LidGuardConstants.hotspotSeriousCPUThreshold,
                LidGuardConstants.hotspotSeriousDuration
            )
        case .critical:
            return (
                LidGuardConstants.hotspotSeriousCPUThreshold,
                LidGuardConstants.hotspotCriticalConfirmationDuration
            )
        case .unknown, .nominal:
            return nil
        }
    }

    private static func isProtected(_ sample: ProcessSample) -> Bool {
        let name = sample.displayName.lowercased()
        if ["lidguard", "lidguardapp", "lidguardhelper"].contains(name) {
            return true
        }
        return sample.command.lowercased().contains("/lidguard.app/")
    }

    static func isAllowedOwner(_ sample: ProcessSample, ownerUID: UInt32) -> Bool {
        sample.uid == ownerUID
            || (sample.uid == 0 && sample.command == "/System/Library/CoreServices/ReportCrash")
    }
}

public final class SystemProcessHotspotMonitor: ProcessHotspotMonitoring {
    private let ownerUID: UInt32
    private let detector: HotspotDetector
    private let sampleReader: () throws -> [ProcessSample]
    private let signalSender: (Int32, Int32) -> Bool
    private let wait: (TimeInterval) -> Void
    private let logger = Logger(subsystem: LidGuardConstants.bundleIdentifier, category: "hotspot")
    private var lastTerminationAt: Date?

    public init(
        ownerUID: UInt32,
        detector: HotspotDetector = HotspotDetector(),
        sampleReader: (() throws -> [ProcessSample])? = nil,
        signalSender: @escaping (Int32, Int32) -> Bool = { pid, signal in
            Darwin.kill(pid, signal) == 0
        },
        wait: @escaping (TimeInterval) -> Void = Thread.sleep(forTimeInterval:)
    ) {
        self.ownerUID = ownerUID
        self.detector = detector
        self.sampleReader = sampleReader ?? Self.readSamples
        self.signalSender = signalSender
        self.wait = wait
    }

    public func evaluate(thermalLevel: ThermalLevel, enabled: Bool, now: Date) -> ProcessHotspot? {
        guard enabled else {
            detector.reset()
            return nil
        }
        guard HotspotDetector.policy(for: thermalLevel) != nil else {
            detector.reset()
            return nil
        }
        if let lastTerminationAt,
           now.timeIntervalSince(lastTerminationAt) < LidGuardConstants.hotspotTerminationCooldown {
            return nil
        }

        do {
            let samples = try sampleReader()
            guard let candidate = detector.candidate(
                from: samples,
                ownerUID: ownerUID,
                thermalLevel: thermalLevel,
                now: now
            ), let policy = HotspotDetector.policy(for: thermalLevel) else {
                return nil
            }

            // Re-read immediately before signaling. Matching both PID and start time prevents
            // terminating an unrelated process if macOS has already recycled the PID.
            guard let current = try sampleReader().first(where: {
                $0.pid == candidate.pid && $0.startIdentity == candidate.startIdentity
            }), HotspotDetector.isAllowedOwner(current, ownerUID: ownerUID),
                current.cpuPercent >= policy.cpuThreshold else {
                return nil
            }

            guard signalSender(candidate.pid, SIGTERM) else {
                logger.error(
                    "Unable to terminate PID \(candidate.pid): errno \(errno)"
                )
                return nil
            }

            wait(LidGuardConstants.hotspotTerminationGracePeriod)
            if try isSameProcessRunning(candidate) {
                guard signalSender(candidate.pid, SIGKILL) else {
                    logger.error(
                        "Unable to force terminate PID \(candidate.pid): errno \(errno)"
                    )
                    return nil
                }
                wait(LidGuardConstants.hotspotForceTerminationCheckDelay)
                guard try !isSameProcessRunning(candidate) else {
                    logger.error("PID \(candidate.pid) remained alive after SIGKILL")
                    return nil
                }
            }

            lastTerminationAt = now
            detector.reset()
            logger.notice(
                "Terminated hotspot \(candidate.displayName, privacy: .public) PID \(candidate.pid) at \(current.cpuPercent)% CPU"
            )
            return ProcessHotspot(
                pid: candidate.pid,
                processName: candidate.displayName,
                cpuPercent: current.cpuPercent,
                thermalLevel: thermalLevel,
                terminatedAt: now
            )
        } catch {
            logger.error("Process sampling failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func isSameProcessRunning(_ candidate: ProcessSample) throws -> Bool {
        try sampleReader().contains {
            $0.pid == candidate.pid && $0.startIdentity == candidate.startIdentity
        }
    }

    private static func readSamples() throws -> [ProcessSample] {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,uid=,%cpu=,lstart=,comm="]
        process.environment = ["LC_ALL": "C", "LANG": "C", "PATH": "/usr/bin:/bin"]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ProcessMonitorError.samplingFailed(message)
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        return output.split(whereSeparator: \.isNewline).compactMap(parseSample)
    }

    private static func parseSample(_ line: Substring) -> ProcessSample? {
        let fields = line.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard fields.count >= 9,
              let pid = Int32(fields[0]),
              let uid = UInt32(fields[1]),
              let cpu = Double(fields[2]) else {
            return nil
        }
        return ProcessSample(
            pid: pid,
            uid: uid,
            cpuPercent: cpu,
            startIdentity: fields[3...7].joined(separator: " "),
            command: fields[8...].joined(separator: " ")
        )
    }
}

private enum ProcessMonitorError: Error, LocalizedError {
    case samplingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .samplingFailed(message):
            return message.isEmpty ? "ps returned a non-zero status" : message
        }
    }
}
