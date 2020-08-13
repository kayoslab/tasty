import Foundation

protocol URLRequestBuilding {

    func urlRequest(withRequest request: Request) throws -> URLRequest
}

final class URLRequestBuilder: URLRequestBuilding {

    private let server: Server

    init(server: Server) {
        self.server = server
    }

    func urlRequest(withRequest request: Request) throws -> URLRequest {
        let url = try prepareUrl(forRequest: request)

        var urlRequest = URLRequest(url: url)

        urlRequest.cachePolicy = server.cachePolicy
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = try prepareBody(forRequest: request)

        let headers = try prepareHeaders(forRequest: request)
        headers.forEach {
            urlRequest.addValue($1, forHTTPHeaderField: $0)
        }

        return urlRequest
    }

    private func prepareBody(forRequest request: Request) throws -> Data? {
        let body: Data?

        switch request.parameters {
        case .bodyJSON(let parameters):
            body = try JSONSerialization.data(withJSONObject: parameters, options: .init(rawValue: 0))
        case .bodyURLEncode(let parameters):
            body = try URLEncodeSerialization.data(withURLObject: parameters)
        case .body(let data):
            body = data
        default:
            body = nil
        }
        return body
    }

    private func prepareUrl(forRequest request: Request) throws -> URL {
        var components = URLComponents(string: request.urlpath)

        if case .url(let parameters) = request.parameters {
            components?.queryItems = try parameters.map {
                guard let value = $0.value as? String else {
                    throw APIError.NetworkError.badInput
                }
                return URLQueryItem(name: $0.key, value: value)
            }
        }

        if let url = components?.url {
            return url
        } else {
            throw APIError.NetworkError.badURL
        }
    }

    private func prepareHeaders(forRequest request: Request) throws -> [String: String] {
        var headers = server.defaultHeaders

        if let requestHeaders = request.headers {
            headers = headers.merging(requestHeaders) { (_, new) in new }
        }

        if let apiKey = (server.apiKeys.first { request.urlpath.contains($0.key) }?.value) {
            headers = headers.merging(["x-api-key": apiKey]) { (_, new) in new }
        }

        return headers
    }
}
