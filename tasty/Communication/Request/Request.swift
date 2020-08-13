//// This is the Request protocol you may implement as enum
/// or as a classic class object for each kind of request.
public protocol Request: CustomReflectable {

    /// Absolute urlpath of the endpoint we want to call
    /// (ie. `#baseurl/users/login`)
    var urlpath: String { get }

    /// This define the HTTP method we should use to perform the call
    /// We have defined it inside an String based enum called `HTTPMethod`
    /// just for clarity
    var method: HTTPMethod { get }

    /// These are the parameters we need to send along with the call.
    /// Params can be passed into the body or along with the URL
    var parameters: RequestParams { get }

    /// You may also define a list of headers to pass along with each request.
    var headers: [String: String]? { get }

    /// What kind of data we expect as response
    var dataType: DataType { get }

    /// What kind of authorization is required to get a valid server response
    var requiredAuthorization: Authorization { get }
}

extension Request {

    public var customMirror: Mirror {
        let children = KeyValuePairs<String, Any>(
            dictionaryLiteral:
                ("urlpath", urlpath),
                ("method", method),
                ("parameters", parameters),
                ("headers", headers as Any),
                ("dataType", dataType),
                ("requiredAuthorization", requiredAuthorization)
        )

        return Mirror(
            Request.self,
            children: children,
            displayStyle: .class,
            ancestorRepresentation: .suppressed
        )
    }
}

/// Define the type of data we expect as response
///
/// - json: it's a json
/// - data: it's plain data
public enum DataType {
    case json
    case data
}

public enum Authorization {
    case none
    case accessToken
}

/// This define the type of HTTP method used to perform the request
///
/// - post: POST method
/// - put: PUT method
/// - get: GET method
/// - delete: DELETE method
/// - patch: PATCH method
public enum HTTPMethod: String {
    case post = "POST"
    case put = "PUT"
    case get = "GET"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// Define parameters to pass along with the request and how
/// they are encapsulated into the http request itself.
///
/// - bodyJSON: part of the body stream using a JSON encoding
/// - bodyURLEncode: part of the body stream using a URL encoding
/// - url: as url parameters
/// - empty: no data
public enum RequestParams {
    case body(Data)
    case bodyJSON([String: Any?])
    case bodyURLEncode([String: Any?])
    case url([String: Any?])
    case empty

    //convenience for logging
    public var parameterString: String {
        do {
            switch self {
            case .bodyJSON(let parameters):
                if let data = try? JSONSerialization.data(withJSONObject: parameters, options: .init(rawValue: 0)),
                    let bodyString = String(data: data, encoding: .utf8) {
                    return bodyString
                }
            case .bodyURLEncode(let parameters):
                if let data = try? URLSerialization.data(withURLObject: parameters),
                    let bodyString = String(data: data, encoding: .utf8) {
                    return bodyString
                }
            case .body(let data):
                if let bodyString = String(data: data, encoding: .utf8) {
                    return bodyString
                }
            default:
                return "Empty Parameters"
            }
            return "Invalid Parameters"
        }
    }
}
