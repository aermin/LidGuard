import Foundation

@objc(LidGuardHelperProtocol)
public protocol LidGuardHelperProtocol: NSObjectProtocol {
    func fetchStatus(withReply reply: @escaping (NSData?, NSString?) -> Void)
    func startSession(_ request: NSData, withReply reply: @escaping (NSData?, NSString?) -> Void)
    func updateSession(_ request: NSData, withReply reply: @escaping (NSData?, NSString?) -> Void)
    func stopSession(_ request: NSData, withReply reply: @escaping (NSData?, NSString?) -> Void)
}

public enum HelperClientError: Error, LocalizedError {
    case unavailable(String)
    case timeout
    case invalidReply
    case remote(String)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(message): return "Helper 不可用：\(message)"
        case .timeout: return "Helper 响应超时"
        case .invalidReply: return "Helper 返回了无效数据"
        case let .remote(message): return message
        }
    }
}
