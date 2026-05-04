import Foundation

/// M048: All fenced code blocks must use the same fence marker (backtick or tilde).
///
/// Mirrors markdownlint's MD048 (code-fence-style) with the default `style: "consistent"`.
public struct M048_CodeFenceStyle: Rule {
    public let code = "M048"
    public let description = "Fenced code blocks must use a consistent marker"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        var violations: [Violation] = []
        var expected: FenceMarker?
        for block in blocks {
            guard case .fencedCode(let marker, _) = block.kind else { continue }
            if let baseline = expected {
                if baseline != marker {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Fence marker does not match first-use marker",
                            line: block.startLine,
                            context: ["expected": "\(baseline)", "actual": "\(marker)"]
                        )
                    )
                }
            } else {
                expected = marker
            }
        }
        return violations
    }
}
