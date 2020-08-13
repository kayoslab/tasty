public protocol Token {

    /// Access token to put into requests using e.g. the Authorization header field.
    /// The value returned must contain the token type. E.g. return `Bearer eyJhbGciO[...]`
    var accessToken: String { get }

    /// Boolean indicating wether the access token valid and not yet expired
    var isValid: Bool { get }

    /// Boolean indicating wether the refresh token can be used for receiving a new access token and is not yet expired.
    var canRefresh: Bool { get }

    /// Sepcifies the Token's type.
    var tokenType: TokenType { get }
}

public enum TokenType: String, Codable {
    case bearer = "Bearer"
}
