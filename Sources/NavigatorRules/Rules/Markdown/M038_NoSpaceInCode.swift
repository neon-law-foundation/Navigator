import Foundation

/// M038: Code spans must not have leading or trailing spaces inside their backticks.
///
/// Mirrors markdownlint's MD038 (no-space-in-code). `` ` foo ` `` should be `` `foo` ``. A
/// single space on each side is permitted when the content itself starts or ends with a
/// backtick (e.g. `` `` `text` `` ``), per CommonMark's "one space each side is stripped" rule.
public struct M038_NoSpaceInCode: Rule {
    public let code = "M038"
    public let description = "Code spans must not have internal padding"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let skipLines = ReferenceCollector.linesToSkip(content: content)

        var violations: [Violation] = []
        for line in LineScanner.scan(content) {
            if skipLines.contains(line.number) { continue }
            if line.isInFrontmatter { continue }
            for span in InlineTokenizer.codeSpans(in: line.raw) {
                let content = String(line.raw[span.contentRange])
                if content.isEmpty { continue }
                if Self.hasPaddingViolation(content) {
                    violations.append(
                        Violation(
                            ruleCode: code,
                            message: "Code span has leading or trailing spaces inside backticks",
                            line: line.number,
                            context: ["content": content]
                        )
                    )
                }
            }
        }
        return violations
    }

    /// CommonMark strips exactly one leading and one trailing space when the content begins AND
    /// ends with a space and contains a non-space character. MD038 flags padding OUTSIDE that
    /// stripping rule — i.e. one side has a space but the other doesn't, or more than one space.
    static func hasPaddingViolation(_ content: String) -> Bool {
        guard !content.isEmpty else { return false }
        var leadingSpaces = 0
        for ch in content {
            if ch == " " || ch == "\t" {
                leadingSpaces += 1
            } else {
                break
            }
        }
        // All-whitespace content is a separate case — markdownlint does not flag it.
        if leadingSpaces == content.count { return false }
        var trailingSpaces = 0
        for ch in content.reversed() {
            if ch == " " || ch == "\t" {
                trailingSpaces += 1
            } else {
                break
            }
        }
        if leadingSpaces == 0, trailingSpaces == 0 { return false }
        // CommonMark stripping rule: exactly one leading + one trailing space is allowed.
        if leadingSpaces == 1, trailingSpaces == 1 { return false }
        return true
    }
}
