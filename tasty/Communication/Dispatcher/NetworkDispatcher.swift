import Foundation

extension NetworkDispatcher: SessionServerTrustProvider { }

/// Dispatcher using a URLSession to exectute requests.
public final class NetworkDispatcher: Dispatcher {

    public var delegate: TokenDelegate? {
        didSet {
            requestDispatcher.delegate = delegate
            tokenRequestDispatcher.delegate = delegate
        }
    }

    public weak var loggingDelegate: Logging? {
        didSet {
            requestDispatcher.loggingDelegate = loggingDelegate
            tokenRequestDispatcher.loggingDelegate = loggingDelegate
        }
    }

    internal var serverTrustManager: ServerTrustManager?

    private var requestDispatcher: Dispatcher
    private var tokenRequestDispatcher: Dispatcher

    public convenience init(server: Server) {
        let sessionDelegate = SessionDelegate(server: server)
        let session = URLSession(
            configuration: URLSessionConfiguration.default,
            delegate: sessionDelegate,
            delegateQueue: .main
        )
        let requestBuilder = URLRequestBuilder(server: server)
        let requestDispatcher = RequestDispatcher(
            session: session,
            requestBuilder: requestBuilder
        )
        let tokenRequestDispatcher = TokenRequestDispatcher(
            session: session,
            requestBuilder: requestBuilder
        )

        self.init(
            requestDispatcher: requestDispatcher,
            tokenRequestDispatcher: tokenRequestDispatcher
        )
        sessionDelegate.serverTrustProvider = self
        serverTrustManager = ServerTrustManager(evaluators: server.trustEvaluators)
    }

    init(
        requestDispatcher: Dispatcher,
        tokenRequestDispatcher: Dispatcher
    ) {
        self.requestDispatcher = requestDispatcher
        self.tokenRequestDispatcher = tokenRequestDispatcher
    }

    public func execute(request: Request, handler: @escaping (Response) -> Void) throws {
        switch request.requiredAuthorization {
        case .none:
            try requestDispatcher.execute(request: request, handler: handler)
        case .accessToken:
            try tokenRequestDispatcher.execute(request: request, handler: handler)
        }
    }

    public func execute(
        batch: [Request],
        handler: @escaping (Response) -> Void,
        completion: (() -> Void)?
    ) throws {
        let batchWithoutAuthorization = batch
            .allSatisfy({ $0.requiredAuthorization == .none })

        if batchWithoutAuthorization {
            try requestDispatcher.execute(
                batch: batch,
                handler: handler,
                completion: completion
            )
        } else {
            try tokenRequestDispatcher.execute(
                batch: batch,
                handler: handler,
                completion: completion
            )
        }
    }
}
