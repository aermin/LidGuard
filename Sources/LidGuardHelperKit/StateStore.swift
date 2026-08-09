import Foundation
import LidGuardCore

public protocol StateStoring: AnyObject {
    var hasStoredState: Bool { get }
    func load() throws -> PersistedState
    func save(_ state: PersistedState) throws
}

public final class JSONStateStore: StateStoring {
    private let url: URL

    public init(path: String = LidGuardConstants.statePath) {
        url = URL(fileURLWithPath: path)
    }

    public var hasStoredState: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func load() throws -> PersistedState {
        guard hasStoredState else { return PersistedState() }
        let data = try Data(contentsOf: url)
        return try LidGuardCoding.makeDecoder().decode(PersistedState.self, from: data)
    }

    public func save(_ state: PersistedState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        let data = try LidGuardCoding.makeEncoder(prettyPrinted: true).encode(state)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    }
}
