import Foundation

class RequestDispatcher: Dispatcher {

    weak var delegate: TokenDelegate?
    weak var loggingDelegate: Logging?

    let session: URLSessionProtocol
    let requestBuilder: URLRequestBuilding

    required init(server: Server) {
        let session = URLSession(configuration: .default)
        let requestBuilder = URLRequestBuilder(server: server)

        self.session = session
        self.requestBuilder = requestBuilder
    }

    init(
        session: URLSessionProtocol,
        requestBuilder: URLRequestBuilding
    ) {
        self.session = session
        self.requestBuilder = requestBuilder
    }

    func execute(request: Request, handler: @escaping (_ response: Response) -> Void) throws {
        if let headers = request.headers {
            loggingDelegate?.logRequestHeader(header: headers)
        }
        loggingDelegate?.logRequestParameters(body: request.parameters.parameterString)
        let urlRequest = try requestBuilder.urlRequest(withRequest: request)

        execute(request: urlRequest, handler: handler)
    }

    func execute(
        batch: [Request],
        handler: @escaping (_ response: Response) -> Void,
        completion: (() -> Void)?
    ) throws {
        guard let requests = try? batch.map({ (request) -> URLRequest in
                if let headers = request.headers {
                    loggingDelegate?.logRequestHeader(header: headers)
                }
                self.loggingDelegate?.logRequestParameters(body: request.parameters.parameterString)

                let urlRequest = try self.requestBuilder.urlRequest(withRequest: request)
                return urlRequest
            }
        ) else { return }

        execute(batch: requests, handler: handler, completion: completion)
    }

    func execute(request: URLRequest, handler: @escaping (_ response: Response) -> Void) {
        let dataTask = session.dataTask(with: request) { (data, urlResponse, error) in
            if let response = urlResponse {
                self.loggingDelegate?.logURLResponse(response: response)
            }
            if let bodyData = data, let bodyString = String(data: bodyData, encoding: .utf8) {
                self.loggingDelegate?.logResponsebody(body: bodyString)
            }
            return handler(
                Response(
                    response: (urlResponse as? HTTPURLResponse),
                    data: data,
                    error: error
                )
            )
        }
        dataTask.resume()
    }

    func execute(
        batch: [URLRequest],
        handler: @escaping (_ response: Response) -> Void,
        completion: (() -> Void)?
    ) {
        let group = DispatchGroup()

        for request in batch {
            group.enter()
            execute(request: request) { (response) in
                handler(response)
                group.leave()
            }
        }

        group.notify(queue: DispatchQueue.main) { completion?() }
    }
}
