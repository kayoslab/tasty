import Foundation

final class URLEncodeSerialization: NSObject {

    private struct EncodingError: Error {
    }

    /** Generate URL encoded data from a Foundation object. If the object will not produce valid url encoded string
     then an exception will be thrown. The resulting data is a encoded in UTF-8.
     */
    class func data(withURLObject obj: Any) throws -> Data {
        let encoded: String

        if let dictionary = obj as? [String: Any] {
            let list = try dictionary.map {
                "\(escape($0))=\(try encode($1))"
            }
            encoded = list.joined(separator: "&")
        } else {
            encoded = try encode(obj)
        }

        if let data = encoded.data(using: .utf8, allowLossyConversion: false) {
            return data
        } else {
            throw EncodingError()
        }
    }

    private class func encode(_ value: Any) throws -> String {
        if let string = value as? String {
            return escape(string)
        } else if let number = value as? NSNumber {
            return "\(number)"
        } else {
            throw EncodingError()
        }
    }

    // Based on Alamofire Parameter Encoding
    // https://github.com/Alamofire/Alamofire/blob/master/Source/ParameterEncoding.swift
    private class func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
    }
}
