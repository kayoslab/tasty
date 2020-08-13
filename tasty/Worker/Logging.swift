import Foundation

/// This delegate provides logging functionality for the application that implements the library
public protocol Logging: class {
    func logRequestParameters(body: String)
    func logRequestHeader(header: [String: String])
    func logURLResponse(response: URLResponse)
    func logResponsebody(body: String)
}
