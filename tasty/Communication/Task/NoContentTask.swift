import Foundation

/// Use this task if the response is expected to be a 204 No Content result
public protocol NoContentTask: Task where SuccessType == Void {}

public extension NoContentTask {

    func execute(handler: @escaping Handler) {
        guard let dispatcher = Networking.dispatcher else {
            return handler(.failure(APIError(type: .networkingUnconfigured)))
        }
        do {
            try dispatcher.execute(request: request) {
                switch $0 {
                case .failure(let error):
                    return handler(.failure(error))
                case .success:
                    return handler(.success(Void()))
                }
            }
        } catch {
            return handler(.failure(APIError(type: .badInput)))
        }
    }
}
