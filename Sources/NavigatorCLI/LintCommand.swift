import Foundation
import NavigatorRules

struct LintCommand: Command {
    let path: String
    let markdownOnly: Bool
    let noDefaultExcludes: Bool
    let fix: Bool

    init(
        path: String,
        markdownOnly: Bool = false,
        noDefaultExcludes: Bool = false,
        fix: Bool = false
    ) {
        self.path = path
        self.markdownOnly = markdownOnly
        self.noDefaultExcludes = noDefaultExcludes
        self.fix = fix
    }

    func run() async throws {
        let url: URL
        if path == "." {
            url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        } else {
            url = URL(fileURLWithPath: path)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            print("Error: '\(path)' does not exist")
            throw CommandError.invalidPath(path)
        }

        let rules = markdownOnly ? NavigatorDefaultRules.markdownOnly() : NavigatorDefaultRules.all()
        let excludedFilenames: Set<String> =
            noDefaultExcludes ? [] : FileFilters.defaultExcludedFilenames
        let excludedDirectories: Set<String> =
            noDefaultExcludes ? [] : FileFilters.defaultExcludedDirectories

        let engine = RuleEngine(
            rules: rules,
            excludedFilenames: excludedFilenames,
            excludedDirectories: excludedDirectories
        )

        if fix {
            let fixResult: FixResult
            if isDirectory.boolValue {
                fixResult = try await engine.fix(directory: url)
            } else {
                fixResult = try await engine.fix(file: url)
            }

            print(
                "✓ Fixed \(fixResult.violationsFixed) violation(s) in "
                    + "\(fixResult.filesFixed.count) file(s)"
            )

            if !fixResult.filesFixed.isEmpty {
                for file in fixResult.filesFixed.sorted(by: { $0.path < $1.path }) {
                    print("  \(makeRelativePath(file, from: url))")
                }
            }
            return
        }

        let result = try isDirectory.boolValue ? engine.lint(directory: url) : engine.lint(file: url)

        if result.isValid {
            print("✓ All Markdown files pass all rules")
        } else {
            print(
                "✗ Found \(result.totalViolationCount) violation(s) in \(result.fileViolations.count) file(s):\n"
            )

            for fileViolation in result.fileViolations {
                let relativePath = makeRelativePath(fileViolation.file, from: url)
                print("\(relativePath):")

                for violation in fileViolation.violations {
                    var parts = ["[\(violation.ruleCode)]"]

                    if let line = violation.line {
                        parts.append("Line \(line):")
                    }

                    parts.append(violation.message)

                    if let context = violation.context, !context.isEmpty {
                        let contextStr = context.map { "\($0.key): \($0.value)" }.joined(
                            separator: ", "
                        )
                        parts.append("(\(contextStr))")
                    }

                    print("  " + parts.joined(separator: " "))
                }
                print("")
            }

            throw CommandError.lintFailed
        }
    }

    private func makeRelativePath(_ file: URL, from base: URL) -> String {
        base.path.isEmpty
            ? file.path : file.path.replacingOccurrences(of: base.path + "/", with: "")
    }
}

enum CommandError: Error, LocalizedError {
    case invalidPath(String)
    case lintFailed
    case unknownCommand(String)
    case missingArgument(String)
    case setupFailed(String)
    case platformNotSupported(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .lintFailed:
            return "Lint check failed"
        case .unknownCommand(let command):
            return "Unknown command: \(command)"
        case .missingArgument(let arg):
            return "Missing argument: \(arg)"
        case .setupFailed(let reason):
            return "Setup failed: \(reason)"
        case .platformNotSupported(let reason):
            return "Platform not supported: \(reason)"
        }
    }
}
