import Foundation
import LidGuardCore
import os

public final class HelperService: NSObject, LidGuardHelperProtocol {
    private let engine: GuardEngine

    public init(engine: GuardEngine) {
        self.engine = engine
    }

    public func fetchStatus(withReply reply: @escaping (NSData?, NSString?) -> Void) {
        reply(encode(engine.status()), nil)
    }

    public func startSession(_ request: NSData, withReply reply: @escaping (NSData?, NSString?) -> Void) {
        respond(reply) {
            let decoded = try LidGuardCoding.makeDecoder().decode(SessionRequest.self, from: request as Data)
            return try engine.start(request: decoded)
        }
    }

    public func updateSession(_ request: NSData, withReply reply: @escaping (NSData?, NSString?) -> Void) {
        respond(reply) {
            let decoded = try LidGuardCoding.makeDecoder().decode(UpdateSessionRequest.self, from: request as Data)
            return try engine.update(request: decoded)
        }
    }

    public func stopSession(_ request: NSData, withReply reply: @escaping (NSData?, NSString?) -> Void) {
        respond(reply) {
            let decoded = try LidGuardCoding.makeDecoder().decode(StopRequest.self, from: request as Data)
            return try engine.stop(request: decoded)
        }
    }

    private func respond<T: Encodable>(
        _ reply: @escaping (NSData?, NSString?) -> Void,
        operation: () throws -> T
    ) {
        do {
            reply(encode(try operation()), nil)
        } catch {
            reply(nil, error.localizedDescription as NSString)
        }
    }

    private func encode<T: Encodable>(_ value: T) -> NSData? {
        try? LidGuardCoding.makeEncoder().encode(value) as NSData
    }
}

public final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service: HelperService
    private let ownerUID: uid_t
    private let logger = Logger(subsystem: LidGuardConstants.bundleIdentifier, category: "xpc")

    public init(service: HelperService, ownerUID: uid_t) {
        self.service = service
        self.ownerUID = ownerUID
    }

    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        guard newConnection.effectiveUserIdentifier == ownerUID else {
            logger.error("Rejected UID \(newConnection.effectiveUserIdentifier)")
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: LidGuardHelperProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}
