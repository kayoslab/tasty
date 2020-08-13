import Foundation

/// The dispatcher is responsible to execute a Request
/// by calling the underlying layer (maybe URLSession, Alamofire
/// or just a fake dispatcher which return mocked results).
/// As output for a Request it should provide a Response.
public protocol Dispatcher {

    /// A delegate providing the dispatcher with token to perform authenticated requests
    var delegate: TokenDelegate? { get set }

    /// A delegate providing logging functionality
    var loggingDelegate: Logging? { get set }

    /// Configure the dispatcher with an environment
    ///
    /// - Parameter server: Configures the server environment
    init(server: Server)

    /// This function execute the request and provide a Promise
    /// with the response.
    ///
    /// - Parameter request: request to execute
    /// - Parameter handler: handler for request with response
    func execute(request: Request, handler: @escaping (_ response: Response) -> Void) throws

    /// This function executes a batch of requests and provide a Promise
    /// with the response.
    ///
    /// - Parameter request: request to execute
    /// - Parameter handler: handler for request with response
    /// - Parameter completion: the batch is fully performed
    func execute(
        batch: [Request],
        handler: @escaping (Response) -> Void,
        completion: (() -> Void)?
    ) throws

}

/// Object responsible for providing tokens for a sispatcher
public protocol TokenDelegate: class {

    /// Token used for authentication
    var token: Token? { get }

    /// Function responsible for refreshing an existing token. How the token is refreshed is up to the delegate.
    /// This might happen by executing a network request using the dispatcher that requested the refresh.
    ///
    /// - Parameter handler: handler for supplying a token or error back to the caller
    func refreshToken(handler: @escaping (Result<Token, APIError>) -> Void)

    /// Function responsible to retrive a new token. The current refresh token can't be used anymore.
    /// How this is done is up to the delegate. This might happen by relaunching the application
    /// to handle possible state issues.
    func getNewToken()
}
