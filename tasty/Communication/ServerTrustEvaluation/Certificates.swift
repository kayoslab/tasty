import Foundation

struct Certificates {
//    static let starfieldServiceRoot = Certificates.certificate(
//        filename: "SFSRootCAG2", filetype: "cer"
//    )

    private static func certificate(filename: String, filetype: String) -> SecCertificate {
        // swiftlint:disable superfluous_disable_command
        // swiftlint:disable:next force_unwrapping
        let filePath = Bundle.main.path(forResource: filename, ofType: filetype)!
        // swiftlint:disable:next force_try
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        // swiftlint:disable:next force_unwrapping
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!

        return certificate
  }
}
