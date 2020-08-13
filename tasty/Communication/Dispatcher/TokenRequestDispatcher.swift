import Foundation

enum TokenRequestDispatcherError: Error {
    case delegateMissing
}

final class TokenRequestDispatcher: RequestDispatcher {

    override func execute(
        request: Request,
        handler: @escaping (_ response: Response) -> Void
    ) throws {
        if let headers = request.headers {
            loggingDelegate?.logRequestHeader(header: headers)
        }
        loggingDelegate?.logRequestParameters(body: request.parameters.parameterString)

        guard let delegate = delegate else {
            throw TokenRequestDispatcherError.delegateMissing
        }

        guard let token = delegate.token else {
            delegate.getNewToken()
            return handler(.failure(APIError(type: .unauthorized)))
        }

        let urlRequest = try requestBuilder.urlRequest(withRequest: request)

        if token.isValid {
            execute(request: urlRequest, token: token) { (result) in
                switch result {
                case .success:
                    return handler(result)
                case .failure(let error):
                    if error.statusCode == 403 {
                        delegate.refreshToken { [weak self] result in
                            switch result {
                            case .success(let newToken):
                                self?.execute(request: urlRequest, token: newToken, handler: handler)
                            case .failure(let error):
                                if error.statusCode == 403 {
                                    delegate.getNewToken()
                                    return
                                }
                                return handler(.failure(error))
                            }
                        }
                    }
                    return handler(.failure(error))
                }
            }
        } else if token.canRefresh {
            delegate.refreshToken { [weak self] result in
                switch result {
                case .success(let newToken):
                    self?.execute(request: urlRequest, token: newToken, handler: handler)
                case .failure(let error):
                    if error.statusCode == 403 {
                        delegate.getNewToken()
                        return
                    }
                    return handler(.failure(error))
                }
            }
        } else {
            delegate.getNewToken()
            return handler(.failure(APIError(type: .unauthorized)))
        }
    }

    override func execute(
        batch: [Request],
        handler: @escaping (_ response: Response) -> Void,
        completion: (() -> Void)?
    ) throws {
        guard let delegate = delegate else {
            throw TokenRequestDispatcherError.delegateMissing
        }

        guard let token = delegate.token else {
            return handler(.failure(APIError(type: .unauthorized)))
        }

        guard let requests = try? batch.map({ (request) -> URLRequest in
                if let headers = request.headers {
                    loggingDelegate?.logRequestHeader(header: headers)
                }
                self.loggingDelegate?.logRequestParameters(body: request.parameters.parameterString)

                let urlRequest = try self.requestBuilder.urlRequest(withRequest: request)
                return urlRequest
            }
        ) else { return }

        if token.isValid {
            execute(
                batch: requests,
                token: token,
                handler: { (result) in
                    switch result {
                    case .success:
                        return handler(result)
                    case .failure(let error):
                        if error.statusCode == 403 {
                            delegate.refreshToken { [weak self] result in
                                switch result {
                                case .success(let newToken):
                                    self?.execute(
                                        batch: requests,
                                        token: newToken,
                                        handler: handler,
                                        completion: completion
                                    )
                                case .failure(let error):
                                    if error.statusCode == 403 {
                                        delegate.getNewToken()
                                        return
                                    }
                                    return handler(.failure(error))
                                }
                            }
                        }
                        return handler(.failure(error))
                    }
                },
                completion: completion
            )
        } else if token.canRefresh {
            delegate.refreshToken { [weak self] result in
                switch result {
                case .success(let newToken):
                    self?.execute(
                        batch: requests,
                        token: newToken,
                        handler: handler,
                        completion: completion
                    )
                case .failure(let error):
                    if error.statusCode == 403 {
                        delegate.getNewToken()
                        return
                    }

                    handler(.failure(error))
                    completion?()
                    return
                }
            }
        } else {
            handler(.failure(APIError(type: .unauthorized)))
            delegate.getNewToken()
        }
    }

    func execute(request: URLRequest, token: Token, handler: @escaping (Response) -> Void) {
        if let headers = request.allHTTPHeaderFields {
            loggingDelegate?.logRequestHeader(header: headers)
        }
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            loggingDelegate?.logRequestParameters(body: bodyString)
        }

        var request = request
        request.addValue("\(token.tokenType.rawValue) \(token.accessToken)", forHTTPHeaderField: "Authorization")

        super.execute(request: request, handler: handler)
    }

    func execute(
        batch: [URLRequest],
        token: Token,
        handler: @escaping (_ response: Response) -> Void,
        completion: (() -> Void)?
    ) {
        let group = DispatchGroup()

        for request in batch {
            group.enter()
            execute(request: request, token: token) { (response) in
                handler(response)
                group.leave()
            }
        }

        group.notify(queue: DispatchQueue.main) { completion?() }
    }
}
