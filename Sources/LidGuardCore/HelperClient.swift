import Foundation

public final class HelperClient {
    private let connection: NSXPCConnection

    public init() {
        connection = NSXPCConnection(
            machServiceName: LidGuardConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: LidGuardHelperProtocol.self)
        connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    public func fetchStatus(timeout: TimeInterval = 3) throws -> StatusSnapshot {
        try perform(timeout: timeout) { proxy, finish in
            proxy.fetchStatus { data, error in
                finish(Self.decode(StatusSnapshot.self, data: data, error: error))
            }
        }
    }

    public func start(_ request: SessionRequest, timeout: TimeInterval = 5) throws -> OperationResult {
        let payload = try LidGuardCoding.makeEncoder().encode(request) as NSData
        return try perform(timeout: timeout) { proxy, finish in
            proxy.startSession(payload) { data, error in
                finish(Self.decode(OperationResult.self, data: data, error: error))
            }
        }
    }

    public func update(_ request: UpdateSessionRequest, timeout: TimeInterval = 5) throws -> OperationResult {
        let payload = try LidGuardCoding.makeEncoder().encode(request) as NSData
        return try perform(timeout: timeout) { proxy, finish in
            proxy.updateSession(payload) { data, error in
                finish(Self.decode(OperationResult.self, data: data, error: error))
            }
        }
    }

    public func stop(_ request: StopRequest = StopRequest(), timeout: TimeInterval = 5) throws -> OperationResult {
        let payload = try LidGuardCoding.makeEncoder().encode(request) as NSData
        return try perform(timeout: timeout) { proxy, finish in
            proxy.stopSession(payload) { data, error in
                finish(Self.decode(OperationResult.self, data: data, error: error))
            }
        }
    }

    private func perform<T>(
        timeout: TimeInterval,
        operation: (LidGuardHelperProtocol, @escaping (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var storedResult: Result<T, Error>?

        func finish(_ result: Result<T, Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard storedResult == nil else { return }
            storedResult = result
            semaphore.signal()
        }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            finish(.failure(HelperClientError.unavailable(error.localizedDescription)))
        }) as? LidGuardHelperProtocol else {
            throw HelperClientError.unavailable("无法创建 XPC 代理")
        }

        operation(proxy, finish)

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw HelperClientError.timeout
        }

        lock.lock()
        let result = storedResult
        lock.unlock()

        guard let result else {
            throw HelperClientError.invalidReply
        }
        return try result.get()
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        data: NSData?,
        error: NSString?
    ) -> Result<T, Error> {
        if let error {
            return .failure(HelperClientError.remote(error as String))
        }
        guard let data else {
            return .failure(HelperClientError.invalidReply)
        }
        do {
            return .success(try LidGuardCoding.makeDecoder().decode(type, from: data as Data))
        } catch {
            return .failure(error)
        }
    }
}
