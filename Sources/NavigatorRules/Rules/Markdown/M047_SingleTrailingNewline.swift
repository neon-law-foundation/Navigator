import Foundation

/// M047: Files must end with exactly one trailing newline.
///
/// Mirrors markdownlint's MD047 (single-trailing-newline).
public struct M047_SingleTrailingNewline: FixableRule {
    public let code = "M047"
    public let description = "Files must end with exactly one newline"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        guard !content.isEmpty else { return [] }

        if !content.hasSuffix("\n") {
            return [
                Violation(
                    ruleCode: code,
                    message: "File does not end with a newline"
                )
            ]
        }

        if content.hasSuffix("\n\n") {
            return [
                Violation(
                    ruleCode: code,
                    message: "File ends with more than one trailing newline"
                )
            ]
        }

        return []
    }

    public func fix(file: URL) async throws -> Int {
        let violationsBeforeFix = try validate(file: file)
        guard !violationsBeforeFix.isEmpty else { return 0 }

        let content = try String(contentsOf: file, encoding: .utf8)
        var trimmed = content
        while trimmed.hasSuffix("\n") {
            trimmed.removeLast()
        }
        let fixed = trimmed + "\n"
        try fixed.write(to: file, atomically: true, encoding: .utf8)
        return violationsBeforeFix.count
    }
}
