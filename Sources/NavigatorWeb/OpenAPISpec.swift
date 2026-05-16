import Foundation

/// Access to the OpenAPI specification document bundled with this target.
///
/// The spec is the contract for the JSON API served at `/api/...`. It is
/// also published verbatim at `GET /openapi.yaml` so external clients can
/// discover the contract without cloning this repository.
public enum OpenAPISpec {
    /// File extension and MIME type advertised when serving the spec.
    public static let contentType: String = "application/yaml; charset=utf-8"

    /// Loads the bundled `openapi.yaml` resource as a UTF-8 string.
    ///
    /// - Throws: `OpenAPISpecError.resourceMissing` if the resource is not
    ///   bundled (a build configuration regression), or any error raised
    ///   by `String(contentsOf:encoding:)` while reading the file.
    public static func yamlContents() throws -> String {
        guard let url = Bundle.module.url(forResource: "openapi", withExtension: "yaml") else {
            throw OpenAPISpecError.resourceMissing
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// Errors raised while loading the bundled OpenAPI specification.
public enum OpenAPISpecError: Error, CustomStringConvertible {
    case resourceMissing

    public var description: String {
        switch self {
        case .resourceMissing:
            return "openapi.yaml resource is not bundled with NavigatorWeb"
        }
    }
}
