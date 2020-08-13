import Combine

/// An extension for the networking service that allows to create observable network tasks which
/// then can be used by `SwiftUI`.
public final class ObservableTask<A>: ObservableObject where A: Task {
    /// Will change notification
    public let objectWillChange = ObservableObjectPublisher()
    /// Did change notification
    public let didChange = PassthroughSubject<A.SuccessType, APIError>()
    /// The underlying task which should be executed.
    private let task: A
    
    /// The response data in case the task's execution was successful.
    public var data: A.SuccessType? {
        willSet {
            objectWillChange.send()
        }
        
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let value = self?.data else { return }
                self?.didChange.send(value)
            }
        }
    }
    
    /// The response data in case the task's execution resulted in an error.
    public var error: APIError? {
        willSet {
            objectWillChange.send()
        }
        
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let error = self?.error else { return }
                self?.didChange.send(completion: .failure(error))
            }
        }
    }

    public init(task: A) {
        self.task = task
        reload()
    }

    /// Call this function to load/reload the task data.
    public func reload() {
        task.execute { [weak self] (result) in
            switch result {
            case .success(let value):
                self?.data = value
            case .failure(let error):
                self?.error = error
            }
        }
    }
}
