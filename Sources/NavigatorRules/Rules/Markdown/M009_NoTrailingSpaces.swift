import Foundation

/// M009: Lines must not contain trailing whitespace.
///
/// Mirrors markdownlint's MD009 (no-trailing-spaces). Matches the upstream default of
/// allowing exactly two trailing spaces on a non-blank line as a hard-break marker.
public struct M009_NoTrailingSpaces: FixableRule {
    public let code = "M009"
    public let description = "Lines must not have trailing whitespace"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        return Self.violations(in: content, ruleCode: code)
    }

    public func fix(file: URL) async throws -> Int {
        let violationsBeforeFix = try validate(file: file)
        guard !violationsBeforeFix.isEmpty else { return 0 }

        let content = try String(contentsOf: file, encoding: .utf8)
        let fixed = Self.stripTrailingWhitespace(in: content)
        try fixed.write(to: file, atomically: true, encoding: .utf8)
        return violationsBeforeFix.count
    }

    /// Enumerate every line with trailing whitespace that is not a valid two-space hard break.
    static func violations(in content: String, ruleCode: String) -> [Violation] {
        var violations: [Violation] = []
        for line in LineScanner.scan(content) {
            if isViolation(raw: line.raw) {
                violations.append(
                    Violation(
                        ruleCode: ruleCode,
                        message: "Line has trailing whitespace",
                        line: line.number
                    )
                )
            }
        }
        return violations
    }

    /// Rebuild `content` with trailing whitespace trimmed, preserving two-space hard breaks.
    static func stripTrailingWhitespace(in content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var rebuilt: [String] = []
        rebuilt.reserveCapacity(lines.count)
        for line in lines {
            let hasCR = line.hasSuffix("\r")
            let stripped = stripped(line: hasCR ? String(line.dropLast()) : line)
            rebuilt.append(stripped + (hasCR ? "\r" : ""))
        }
        return rebuilt.joined(separator: "\n")
    }

    /// Strip trailing whitespace from one line while preserving a valid two-space hard break.
    private static func stripped(line: String) -> String {
        guard let trailing = trailingWhitespaceRange(of: line) else {
            return line
        }
        let content = String(line[..<trailing.lowerBound])
        if content.isEmpty {
            return ""
        }
        let trailingString = String(line[trailing])
        if trailingString == "  " {
            return line
        }
        return content
    }

    private static func isViolation(raw: String) -> Bool {
        guard let trailing = trailingWhitespaceRange(of: raw) else {
            return false
        }
        let content = String(raw[..<trailing.lowerBound])
        if content.isEmpty {
            return true
        }
        let trailingString = String(raw[trailing])
        return trailingString != "  "
    }

    /// Range covering the run of trailing whitespace at the end of `line`, or nil when there is none.
    private static func trailingWhitespaceRange(of line: String) -> Range<String.Index>? {
        guard let lastNonWhitespace = line.lastIndex(where: { !$0.isWhitespace }) else {
            return line.isEmpty ? nil : line.startIndex..<line.endIndex
        }
        let after = line.index(after: lastNonWhitespace)
        if after == line.endIndex {
            return nil
        }
        return after..<line.endIndex
    }

}
