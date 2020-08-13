import Foundation

public struct Networking {

    /// The backend environment to which requests are sent.
    private static var environment: Environment = .integration

    internal static var server: Server?

    internal static var dispatcher: Dispatcher?

    /// Configures the networking layer with the parameters used to build request urls and
    /// to select the correct server to send the requests to.
    ///
    /// - Parameters:
    ///   - server: The origin where servers are pointing at.
    ///   - environment: The backend environment to which requests are sent.
    ///   - tokenProvider: ...
    ///   - logging: ...
    public static func configure(
        environment: Environment,
        tokenProvider: TokenDelegate? = nil,
        logging: Logging? = nil
    ) {
        let server: Server
        
        switch environment {
        case .integration:
            server = Staging()
        case .production:
            server = Production()
        }
        self.server = server
        URLCache.shared = server.cache
        
        Networking.environment = environment

        self.dispatcher = NetworkDispatcher(server: server)
        self.dispatcher?.delegate = tokenProvider
        self.dispatcher?.loggingDelegate = logging
    }
}

extension Networking {

    /// Thrown when AMLKit cannot be initialized properly.
    public enum NetworkingError: Error {

        /// Boilerplate Error case to indicate an error state when
        /// `isConfiguredProperly` states false.
        case notConfiguredProperly

        /// Initialising a server with public key pinning failed.
        /// I guess someone fucked it up terribly. We should encourage the
        /// user to check for updates since the certificate seems to be wrong.
        case keyPinning
    }
}
