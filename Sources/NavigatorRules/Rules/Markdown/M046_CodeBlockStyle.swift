import Foundation

/// M046: All code blocks in a file must use the same style (fenced or indented).
///
/// Mirrors markdownlint's MD046 (code-block-style) with the default `style: "consistent"`.
public struct M046_CodeBlockStyle: Rule {
    public let code = "M046"
    public let description = "Code blocks must use a consistent style"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let blocks = BlockTokenizer.tokenize(content)

        enum Style: String {
            case fenced
            case indented
        }

        var violations: [Violation] = []
        var expected: Style?
        for block in blocks {
            let style: Style?
            switch block.kind {
            case .fencedCode: style = .fenced
            case .indentedCode: style = .indented
            default: style = nil
            }
            guard let current = style else { continue }
            if let baseline = expected {
                if baseline != current {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Code block style does not match first-use style",
                            line: block.startLine,
                            context: ["expected": baseline.rawValue, "actual": current.rawValue]
                        )
                    )
                }
            } else {
                expected = current
            }
        }
        return violations
    }
}
