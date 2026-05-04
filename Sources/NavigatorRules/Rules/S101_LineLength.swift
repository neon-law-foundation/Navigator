import Foundation

/// S101: All lines must be ≤120 characters
public struct S101_LineLength: FixableRule {
    public let code = "S101"
    public let description = "Line length must not exceed 120 characters"
    private let maxLength = 120

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var violations: [Violation] = []
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let length = line.count

            if length > maxLength {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message: "Line exceeds maximum length",
                        line: lineNumber,
                        context: [
                            "length": "\(length)",
                            "max": "\(maxLength)",
                        ]
                    )
                )
            }
        }

        return violations
    }

    public func fix(file: URL) async throws -> Int {
        let violationsBeforeFix = try validate(file: file)
        let violationCount = violationsBeforeFix.count

        guard violationCount > 0 else {
            return 0
        }

        let prompt = """
            Fix the line length violations in the file at \(file.path).

            All lines in Markdown files must be ≤120 characters. Please:

            1. Break long lines at natural boundaries (spaces, punctuation)
            2. Keep each line as close to 120 characters as possible without exceeding it
            3. Maintain readability and proper Markdown formatting
            4. For long URLs or code, consider using reference-style links
            5. DO NOT change the meaning or content, only reformat for line length

            Edit the file to fix all line length violations.
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/claude")
        process.arguments = ["--dangerously-skip-permissions", "--print", prompt]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ValidationError.fixFailed(file)
        }

        return violationCount
    }
}
