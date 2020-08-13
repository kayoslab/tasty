/// The implementation of handling server challenges took from Alamofire `ServerTrustEvaluation.swift` file
/// https://github.com/Alamofire/Alamofire/blob/master/Source/ServerTrustEvaluation.swift

import Foundation

public protocol ServerTrustEvaluating {
    func evaluate(_ trust: SecTrust, forHost host: String) throws
}

/// Responsible for managing the mapping of `ServerTrustEvaluating` values to given hosts.
internal class ServerTrustManager {
    /// Determines whether all hosts for this `ServerTrustManager` must be evaluated. `true` by default.
    public let allHostsMustBeEvaluated: Bool

    /// The dictionary of policies mapped to a particular host.
    public let evaluators: [String: ServerTrustEvaluating]

    /// Initializes the `ServerTrustManager` instance with the given evaluators.
    ///
    /// Specifying evaluation policies on a per host basis.
    ///
    /// - Parameters:
    ///   - allHostsMustBeEvaluated: The value determining whether all hosts for this instance must be evaluated. `true`
    ///                              by default.
    ///   - evaluators:              A dictionary of evaluators mapped to hosts.
    public init(allHostsMustBeEvaluated: Bool = true, evaluators: [String: ServerTrustEvaluating]) {
        self.allHostsMustBeEvaluated = allHostsMustBeEvaluated
        self.evaluators = evaluators
    }

    /// Returns the `ServerTrustEvaluating` value for the given host, if one is set.
    ///
    /// By default, this method will return the policy that matches the given host.
    ///
    /// - Parameter host: The host to use when searching for a matching policy.
    ///
    /// - Returns:        The `ServerTrustEvaluating` value for the given host if found, `nil` otherwise.
    /// - Throws:         `AuthenticationChallengeError.serverTrustEvaluationFailed`
    ///                   if `allHostsMustBeEvaluated` is `true` and no matching evaluators are found.
    open func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
        guard let evaluator = evaluators[host] else {
            if allHostsMustBeEvaluated {
                throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                    reason: .noRequiredEvaluator(
                        host: host
                    )
                )
            }

            return nil
        }

        return evaluator
    }
}

public enum AuthenticationChallengeError: Error {
    /// Underlying reason a server trust evaluation error occurred.
    public enum ServerTrustFailureReason {
        /// No `ServerTrustEvaluator` was found for the associated host.
        case noRequiredEvaluator(host: String)
        /// No certificates were found with which to perform the trust evaluation.
        case noCertificatesFound
        /// No public keys were found with which to perform the trust evaluation.
        case noPublicKeysFound
        /// During evaluation, application of the associated `SecPolicy` failed.
        case policyApplicationFailed(trust: SecTrust, policy: SecPolicy, status: OSStatus)
        /// During evaluation, setting the associated anchor certificates failed.
        case settingAnchorCertificatesFailed(status: OSStatus, certificates: [SecCertificate])
        /// `SecTrust` evaluation failed with the associated `Error`, if one was produced.
        case trustEvaluationFailed(error: Error?)
        /// Certificate pinning failed.
        case certificatePinningFailed(host: String, trust: SecTrust, pinnedCertificates: [SecCertificate],
            serverCertificates: [SecCertificate])
        /// Public key pinning failed.
        case publicKeyPinningFailed(host: String, trust: SecTrust, pinnedKeys: [SecKey], serverKeys: [SecKey])
        /// Custom server trust evaluation failed due to the associated `Error`.
        case customEvaluationFailed(error: Error)
    }

    case serverTrustEvaluationFailed(reason: ServerTrustFailureReason)
}

/// Uses the pinned certificates to validate the server trust. The server trust is considered valid if one of the pinned
/// certificates match one of the server certificates. Validating both the certificate chain and host
public final class PinnedCertificatesTrustEvaluator: ServerTrustEvaluating {
    private let certificates: [SecCertificate]
    private let acceptSelfSignedCertificates: Bool
    private let performDefaultValidation: Bool
    private let validateHost: Bool

    /// Creates a `PinnedCertificatesTrustEvaluator`.
    ///
    /// - Parameters:
    ///   - certificates:                 The certificates to use to evaluate the trust (`cer`, `crt`, and `der`)
    ///   - acceptSelfSignedCertificates: Adds the provided certificates as anchors for the trust evaluation, allowing
    ///                                   self-signed certificates to pass. `false` by default.
    ///   - performDefaultValidation:     Determines whether default validation should be performed in addition to
    ///                                   evaluating the pinned certificates. `true` by default.
    ///   - validateHost:                 Determines whether or not the evaluator should validate the host, in addition
    ///                                   to performing the default evaluation, even if `performDefaultValidation` is
    ///                                   `false`. `true` by default.
    public init(certificates: [SecCertificate],
                acceptSelfSignedCertificates: Bool = false,
                performDefaultValidation: Bool = true,
                validateHost: Bool = true) {
        self.certificates = certificates
        self.acceptSelfSignedCertificates = acceptSelfSignedCertificates
        self.performDefaultValidation = performDefaultValidation
        self.validateHost = validateHost
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        guard !certificates.isEmpty else {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .noCertificatesFound
            )
        }

        if acceptSelfSignedCertificates {
            try trust.setAnchorCertificates(certificates)
        }

        if performDefaultValidation {
            try trust.performDefaultValidation(forHost: host)
        }

        if validateHost {
            try trust.performValidation(forHost: host)
        }

        let serverCertificatesData = Set(trust.certificateData)
        let pinnedCertificatesData = Set(certificates.data)
        let pinnedCertificatesInServerData = !serverCertificatesData.isDisjoint(
            with: pinnedCertificatesData
        )

        if !pinnedCertificatesInServerData {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .certificatePinningFailed(
                    host: host,
                    trust: trust,
                    pinnedCertificates: certificates,
                    serverCertificates: trust.certificates
                )
            )
        }
    }
}

/// Uses the pinned public keys to validate the server trust. The server trust is considered valid if one of the pinned
/// public keys match one of the server certificate public keys. By validating both the certificate chain and host,
/// public key pinning provides a very secure form of server trust validation mitigating most, if not all, MITM attacks.
/// Applications are encouraged to always validate the host and require a valid certificate chain in production
/// environments.
public final class PublicKeysTrustEvaluator: ServerTrustEvaluating {
    private let keys: [SecKey]
    private let performDefaultValidation: Bool
    private let validateHost: Bool

    /// Creates a `PublicKeysTrustEvaluator`.
    ///
    /// - Note: Default and host validation will fail when using this evaluator with self-signed certificates. Use
    ///         `PinnedCertificatesTrustEvaluator` if you need to use self-signed certificates.
    ///
    /// - Parameters:
    ///   - keys:                     The `SecKey`s to use to validate public keys. Defaults to the public keys of all
    ///                               certificates included in the main bundle.
    ///   - performDefaultValidation: Determines whether default validation should be performed in addition to
    ///                               evaluating the pinned certificates. `true` by default.
    ///   - validateHost:             Determines whether or not the evaluator should validate the host, in addition to
    ///                               performing the default evaluation, even if `performDefaultValidation` is `false`.
    ///                               `true` by default.
    public init(keys: [SecKey],
                performDefaultValidation: Bool = true,
                validateHost: Bool = true) {
        self.keys = keys
        self.performDefaultValidation = performDefaultValidation
        self.validateHost = validateHost
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        guard !keys.isEmpty else {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .noPublicKeysFound
            )
        }

        if performDefaultValidation {
            try trust.performDefaultValidation(forHost: host)
        }

        if validateHost {
            try trust.performValidation(forHost: host)
        }

        let pinnedKeysInServerKeys: Bool = {
            for serverPublicKey in trust.publicKeys {
                for pinnedPublicKey in keys where serverPublicKey == pinnedPublicKey {
                    return true
                }
            }
            return false
        }()

        if !pinnedKeysInServerKeys {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .publicKeyPinningFailed(
                    host: host,
                    trust: trust,
                    pinnedKeys: keys,
                    serverKeys: trust.publicKeys
                )
            )
        }
    }
}

internal extension SecTrust {

    func evaluate(afterApplying policy: SecPolicy) throws {
        try apply(policy: policy).evaluate()
    }

    /// Applies a `SecPolicy` to `self`, throwing if it fails.
    ///
    /// - Parameter policy: The `SecPolicy`.
    ///
    /// - Returns: `self`, with the policy applied.
    /// - Throws: An `AuthenticationChallengeError.serverTrustEvaluationFailed` instance
    ///           with a `.policyApplicationFailed` reason.
    func apply(policy: SecPolicy) throws -> SecTrust {
        let status = SecTrustSetPolicies(self, policy)

        guard status == errSecSuccess else {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .policyApplicationFailed(
                    trust: self,
                    policy: policy,
                    status: status
                )
            )
        }

        return self
    }

    /// Evaluate `self`, throwing an `Error` if evaluation fails.
    ///
    /// - Throws: `AuthenticationChallengeError.serverTrustEvaluationFailed` with
    ///           reason `.trustValidationFailed` and associated error from the underlying evaluation.
    func evaluate() throws {
        var error: CFError?
        let evaluationSucceeded = SecTrustEvaluateWithError(self, &error)

        if !evaluationSucceeded {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .trustEvaluationFailed(
                    error: error
                )
            )
        }
    }

    /// Sets a custom certificate chain on `self`, allowing full validation of a self-signed certificate and its chain.
    ///
    /// - Parameter certificates: The `SecCertificate`s to add to the chain.
    /// - Throws:                 Any error produced when applying the new certificate chain.
    func setAnchorCertificates(_ certificates: [SecCertificate]) throws {
        // Add additional anchor certificates.
        let status = SecTrustSetAnchorCertificates(self, certificates as CFArray)
        guard status.isSuccess else {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .settingAnchorCertificatesFailed(
                    status: status,
                    certificates: certificates
                )
            )
        }

        // Reenable system anchor certificates.
        let systemStatus = SecTrustSetAnchorCertificatesOnly(self, true)
        guard systemStatus.isSuccess else {
            throw AuthenticationChallengeError.serverTrustEvaluationFailed(
                reason: .settingAnchorCertificatesFailed(
                    status: systemStatus,
                    certificates: certificates
                )
            )
        }
    }

    /// The public keys contained in `self`.
    var publicKeys: [SecKey] {
        return certificates.publicKeys
    }

    /// The `SecCertificate`s contained i `self`.
    var certificates: [SecCertificate] {
        return (0..<SecTrustGetCertificateCount(self)).compactMap { index in
            SecTrustGetCertificateAtIndex(self, index)
        }
    }

    /// The `Data` values for all certificates contained in `self`.
    var certificateData: [Data] {
        return certificates.data
    }

    /// Validates `self` after applying `SecPolicy.default`. This evaluation does not validate the hostname.
    ///
    /// - Parameter host: The hostname, used only in the error output if validation fails.
    /// - Throws: `AuthenticationChallengeError.serverTrustEvaluationFailed` with
    ///           reason `.trustValidationFailed` and associated error from the underlying evaluation.
    func performDefaultValidation(forHost host: String) throws {
        try evaluate(afterApplying: SecPolicy.default)
    }

    /// Validates `self` after applying `SecPolicy.hostname(host)`, which performs the default validation as well as
    /// hostname validation.
    ///
    /// - Parameter host: The hostname to use in the validation.
    /// - Throws: `AuthenticationChallengeError.serverTrustEvaluationFailed` with
    /// reason `.trustValidationFailed` and associated error from the underlying evaluation.
    func performValidation(forHost host: String) throws {
        try evaluate(afterApplying: SecPolicy.hostname(host))
    }
}

internal extension SecCertificate {
    /// The public key for `self`, if it can be extracted.
    var publicKey: SecKey? {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(self, policy, &trust)

        guard let createdTrust = trust, trustCreationStatus == errSecSuccess else { return nil }

        return SecTrustCopyPublicKey(createdTrust)
    }
}

internal extension SecPolicy {
    /// Creates a `SecPolicy` instance which will validate server certificates but not require a host name match.
    static let `default` = SecPolicyCreateSSL(true, nil)

    /// Creates a `SecPolicy` instance which will validate server certificates and much match the provided hostname.
    ///
    /// - Parameter hostname: The hostname to validate against.
    ///
    /// - Returns:            The `SecPolicy`.
    static func hostname(_ hostname: String) -> SecPolicy {
        return SecPolicyCreateSSL(true, hostname as CFString)
    }
}

internal extension Array where Element == SecCertificate {
    /// All `Data` values for the contained `SecCertificate`s.
    var data: [Data] {
        return map { SecCertificateCopyData($0) as Data }
    }

    /// All public `SecKey` values for the contained `SecCertificate`s.
    var publicKeys: [SecKey] {
        return compactMap { $0.publicKey }
    }
}

internal extension OSStatus {
    /// Returns whether `self` is `errSecSuccess`.
    var isSuccess: Bool { return self == errSecSuccess }
}

internal extension SecTrustResultType {
    /// Returns whether `self is `.unspecified` or `.proceed`.
    var isSuccess: Bool {
        return (self == .unspecified || self == .proceed)
    }
}
