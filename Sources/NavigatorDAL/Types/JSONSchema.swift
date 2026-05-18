import Foundation

/// Accessors for the JSON Schema documents bundled with NavigatorDAL.
///
/// Each persisted JSON payload type has a companion schema under
/// `Sources/NavigatorDAL/Schemas/` that documents the wire format and
/// participates in the round-trip tests under `JSONSchemaRoundTripTests`.
///
/// Schemas are JSON Schema Draft 2020-12 documents. The Swift type
/// definitions in `NavigatorDAL/Types/` are the source of truth; the schemas
/// mirror them and the round-trip tests guarantee the two stay in sync.
public enum JSONSchema {

    /// The canonical names of every persisted JSON payload that ships with a
    /// schema document. Used by tests and tools to enumerate the set.
    public enum Name: String, CaseIterable, Sendable {
        case frontmatter = "Frontmatter"
        case questionnaire = "Questionnaire"
        case workflow = "Workflow"
        case notationEvent = "NotationEvent"
        case questionChoices = "QuestionChoices"

        fileprivate var resourceName: String { rawValue }
    }

    /// Returns the raw schema document bytes for the given payload name.
    ///
    /// Resolves through `Bundle.module` — production callers and tests reach
    /// the same files.
    public static func schemaData(for name: Name) throws -> Data {
        guard
            let url = Bundle.module.url(
                forResource: "Schemas/\(name.resourceName).schema",
                withExtension: "json"
            )
        else {
            throw SchemaError.notBundled(name)
        }
        return try Data(contentsOf: url)
    }

    /// Returns the schema document parsed into a `[String: Any]` tree.
    ///
    /// Use this from tests; production code that needs structural access
    /// should prefer typed access on the Swift payload itself.
    public static func schemaJSON(for name: Name) throws -> [String: Any] {
        let data = try schemaData(for: name)
        guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SchemaError.malformed(name)
        }
        return parsed
    }

    /// Errors raised by schema-resource accessors.
    public enum SchemaError: Error, Equatable {
        /// The schema resource was not present in the bundle.
        case notBundled(Name)
        /// The schema file was present but did not parse as a JSON object.
        case malformed(Name)
    }
}
