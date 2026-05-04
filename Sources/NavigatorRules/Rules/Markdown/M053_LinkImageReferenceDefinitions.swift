import Foundation

/// M053: Reference-link definitions must be used.
///
/// Mirrors markdownlint's MD053 (link-image-reference-definitions). Flags each `[label]: url`
/// whose normalized label is not referenced by any link/image use in the document.
public struct M053_LinkImageReferenceDefinitions: Rule {
    public let code = "M053"
    public let description = "Unused reference-link definitions"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let references = ReferenceCollector.collect(from: content)
        let usedLabels = Set(references.uses.map(\.label))

        var violations: [Violation] = []
        for def in references.definitions {
            if !usedLabels.contains(def.label) {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Reference-link definition is unused",
                        line: def.line,
                        context: ["label": def.rawLabel]
                    )
                )
            }
        }
        return violations
    }
}
