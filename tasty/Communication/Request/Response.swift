import Foundation

/// Network response object that encapsulates reiceived information and data
///
/// - success: Server responded with a status code in between 200 and 299.
/// - failure: Some error occoured. See `NetworkError` for details.
public enum Response {
    case success(Data?)
    case failure(APIError)

    public init(response: HTTPURLResponse?, data: Data?, error: Error?) {
        guard let response = response else {
            self = .failure(APIError(error: error, data: data))
            return
        }

        if (200..<300).contains(response.statusCode) {
            self = .success(data)
        } else {
            self = .failure(APIError(code: response.statusCode, data: data))
        }
    }
}
