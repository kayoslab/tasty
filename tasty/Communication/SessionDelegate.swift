import Foundation

internal protocol SessionServerTrustProvider: AnyObject {
    var serverTrustManager: ServerTrustManager? { get }
}

public class SessionDelegate: NSObject, URLSessionDelegate {
    var server: Server

    weak var serverTrustProvider: SessionServerTrustProvider?

    init(server: Server) {
        self.server = server
        super.init()
    }

    typealias ChallengeEvaluation = (
        disposition: URLSession.AuthChallengeDisposition,
        credential: URLCredential?,
        error: Error?
    )

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard server.publicKeyPinning else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let evaluation: ChallengeEvaluation

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            evaluation = attemptServerTrustAuthentication(with: challenge)
        default:
            evaluation = (.performDefaultHandling, nil, nil)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }

    func attemptServerTrustAuthentication(with challenge: URLAuthenticationChallenge) -> ChallengeEvaluation {
        let host = challenge.protectionSpace.host

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil, nil)
        }

        do {
            guard let evaluator = try serverTrustProvider?.serverTrustManager? .serverTrustEvaluator(
                forHost: host
            ) else {
                return (.performDefaultHandling, nil, nil)
            }

            try evaluator.evaluate(trust, forHost: host)

            return (.useCredential, URLCredential(trust: trust), nil)
        } catch {
            return (
                .cancelAuthenticationChallenge,
                nil,
                AuthenticationChallengeError.serverTrustEvaluationFailed(
                    reason: .customEvaluationFailed(error: error)
                )
            )
        }
    }
}
