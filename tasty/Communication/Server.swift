import Foundation

public enum Environment {
    case integration
    case production
}

/// Encapsulates all information needed to perform a setup of the networking layer.
///
/// - Note: If your app supports multiple environments, you might want to create an enum
///         that conforms to this protocol. You can return the ``defaultHeaders``
///         as computed properties.
public protocol Server {

    /// Public Key Pinning enabled for this environment
    var publicKeyPinning: Bool { get }

    /// A list of policies mapped to particular hosts.
    var trustEvaluators: [String: ServerTrustEvaluating] { get }

    /// A list of API keys mapped to particular hosts.
    var apiKeys: [String: String] { get }

    /// The current environment this is running in.
    var environment: Environment { get }

    /// Cache policy
    var cachePolicy: URLRequest.CachePolicy { get }

    /// The common headers which will be part of every request.
    /// - Note: Some header values might be overridden by a request's own headers.
    var defaultHeaders: [String: String] { get }

    var cache: URLCache { get }
}

/// Staging server for integration builds.
struct Staging: Server {
    var publicKeyPinning: Bool {
        return false
    }

    var trustEvaluators: [String: ServerTrustEvaluating] { return [:] }

    var apiKeys: [String: String] {
        return [:]
    }

    var environment: Environment {
        return .integration
    }

    var cachePolicy: URLRequest.CachePolicy {
        return .useProtocolCachePolicy
    }

    var defaultHeaders: [String: String] {
        return [:]
    }
    
    var cache: URLCache {
        return .init(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 20 * 1024 * 1024,
            diskPath: nil
        )
    }
}

/// Production Server for release builds.
struct Production: Server {

    var publicKeyPinning: Bool {
        return false
    }

    var trustEvaluators: [String: ServerTrustEvaluating] { return [:] }

    var apiKeys: [String: String] {
        return [:]
    }

    var environment: Environment {
        return .integration
    }

    var cachePolicy: URLRequest.CachePolicy {
        return .useProtocolCachePolicy
    }

    var defaultHeaders: [String: String] {
        return [:]
    }
    
    var cache: URLCache {
        return .init(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 20 * 1024 * 1024,
            diskPath: nil
        )
    }
}
