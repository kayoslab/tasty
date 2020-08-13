import Foundation

public protocol Task {
    associatedtype SuccessType
    associatedtype ErrorType

    typealias Handler = (Result<SuccessType, APIError>) -> Void

    /// Request to execute
    var request: Request { get }

    /// Execute request on the local dispatcher.
    ///
    /// - Paramter handler: returns the object you asked for
    func execute(handler: @escaping Handler)
}
