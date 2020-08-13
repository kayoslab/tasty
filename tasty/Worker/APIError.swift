import Foundation

public final class APIError: Error {

    /// Non localized localized description to improve the fallback situation and
    /// the readability of this error object.
    public var localizedDescription: String {
        return error.localizedDescription
    }

    /// Defines different error states that might occur during the useage of this framework
    ///
    /// - networkingUnconfigured: 
    public enum ProcessError: Error {
        case networkingUnconfigured

        var localizedDescription: String {
            switch self {
            case .networkingUnconfigured:
                return "network not configured"
            }
        }
    }

    /// Defines different error states that might occur during a network call
    ///
    /// - badURL: The URL could not be build while preparing the network request.
    /// - badInput: Some data (e.g. to put into http body) is invalid.
    /// - badResult: The error response doesn't fit the `ErrorModel` provided.
    /// - badContent: The server response is valid could not be parsed into the expected output.
    /// - badRequest: The sever resonded with error code 400
    /// - unauthorized: The sever resonded with error code 401
    /// - forbidden: The sever resonded with error code 403
    /// - notFound: The sever resonded with error code 404
    /// - server: Internal server error
    /// - badNetwork: Some underlaying components where unable to fully execute the call due to bad network
    /// - cancelled: The call got cancelled
    /// - fallback: Some undefined error happened
    public enum NetworkError: Error {
        // Request (building) errors
        case badURL
        case badInput
        case badResult

        // Response errors
        case badContent
        case badRequest
        case unauthorized
        case forbidden
        case notFound
        case server(statusCode: Int)

        // URLSession API errors
        case badNetwork(underlayingError: Error)
        case cancelled(underlayingError: Error)

        case fallback(underlayingError: Error?, statusCode: Int?)

        fileprivate init(error: Error?) {
            guard let error = error else {
                self = .fallback(underlayingError: nil, statusCode: nil)
                return
            }

            switch (error as NSError).code {
            case NSURLErrorCancelled:
                self = .cancelled(underlayingError: error)
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                self = .badNetwork(underlayingError: error)
            default:
                self = .fallback(underlayingError: error, statusCode: nil)
            }
        }

        fileprivate init(statusCode: Int) {
            switch statusCode {
            case 400, 422:
                self = .badRequest
            case 401:
                self = .unauthorized
            case 403:
                self = .forbidden
            case 404:
                self = .notFound
            case (500..<600):
                self = .server(statusCode: statusCode)
            default:
                self = .fallback(underlayingError: nil, statusCode: statusCode)
            }
        }

        var localizedDescription: String {
            switch self {
            case .badURL:
                return "bad URL"
            case .badInput:
                return "bad input"
            case .badResult:
                return "bad result"
            case .badContent:
                return "bad content"
            case .badRequest:
                return "bad Request"
            case .unauthorized:
                return "unauthorized"
            case .forbidden:
                return "forbidden"
            case .notFound:
                return "not found"
            case .server(let statusCode):
                return "Status \(statusCode)"
            case .badNetwork(let underlayingError):
                return "bad network - \(underlayingError.localizedDescription)"
            case .cancelled(let underlayingError):
                return "cancelled - \(underlayingError.localizedDescription)"
            case .fallback(let underlayingError, let statusCode):
                return "error - \(underlayingError?.localizedDescription ?? "\(statusCode ?? -1)")"
            }
        }
    }

    /// instance of above enum
    public var error: Error
    /// optional error model parsed from the error response
    public var errorModel: Decodable?
    /// optional status code
    public var statusCode: Int?
    /// optional data object if present
    public var data: Data?

    /// Initializer that could contain raw data
    ///
    /// - Parameters:
    ///   - error: An optional error object
    ///   - data: Optional data
    public init(error: Error?, data: Data? = nil) {
        self.error = NetworkError(error: error)
        self.data = data
    }

    /// Initializer that contains a parsed `ErrorModel`
    ///
    /// - Parameters:
    ///   - error: An error object
    ///   - errorModel: The additional error object
    public init(error: Error, errorModel: Decodable) {
        self.error = NetworkError(error: error)
        self.errorModel = errorModel
    }

    /// Initializer for simple error type
    ///
    /// - Parameters:
    ///   - type: The type of the error
    ///   - data: Optional data
    public init(type: NetworkError, data: Data? = nil) {
        self.error = type
        self.data = data
    }

    /// Initializer that contains code and possible message
    ///
    /// - Parameters:
    ///   - code: The status code of the error
    ///   - data: Optional data
    public init(code: Int, data: Data? = nil) {
        self.statusCode = code
        self.error = NetworkError(statusCode: code)
        self.data = data
    }

    /// Initializer for simple error type
    ///
    /// - Parameter type: The type of the error
    public init(type: ProcessError) {
        self.error = type
    }

    /// Returns an additional error data object
    ///
    /// - Returns: Returns the error object with a specific error type.
    public func getErrorModel<ErrorType: Decodable>() -> ErrorType? {
        return errorModel as? ErrorType
    }
}
