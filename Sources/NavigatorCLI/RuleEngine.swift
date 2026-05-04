import Foundation
import NavigatorRules

/// Orchestrates rule execution across files
public struct RuleEngine {
    private let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }

    /// Run all rules against a single file
    public func lint(file: URL) throws -> LintResult {
        guard FileFilters.shouldValidate(file) else {
            return LintResult(fileViolations: [])
        }

        var violations: [Violation] = []
        for rule in rules {
            let ruleViolations = try rule.validate(file: file)
            violations.append(contentsOf: ruleViolations)
        }

        if violations.isEmpty {
            return LintResult(fileViolations: [])
        }
        return LintResult(fileViolations: [FileViolations(file: file, violations: violations)])
    }

    /// Run all rules against files in a directory
    public func lint(directory: URL) throws -> LintResult {
        let fileManager = FileManager.default
        var allFileViolations: [FileViolations] = []

        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            throw ValidationError.directoryNotAccessible(directory)
        }

        for case let fileURL as URL in enumerator {
            guard FileFilters.shouldValidate(fileURL) else { continue }

            var violations: [Violation] = []
            for rule in rules {
                let ruleViolations = try rule.validate(file: fileURL)
                violations.append(contentsOf: ruleViolations)
            }

            if !violations.isEmpty {
                allFileViolations.append(FileViolations(file: fileURL, violations: violations))
            }
        }

        return LintResult(fileViolations: allFileViolations)
    }

    /// Run auto-fix for all fixable rules
    public func fix(directory: URL) async throws -> FixResult {
        var filesFixed: Set<URL> = []
        var totalFixed = 0

        let filesToFix = try collectFiles(in: directory)

        for fileURL in filesToFix {
            for rule in rules {
                if let fixable = rule as? FixableRule {
                    let fixed = try await fixable.fix(file: fileURL)
                    if fixed > 0 {
                        filesFixed.insert(fileURL)
                        totalFixed += fixed
                    }
                }
            }
        }

        return FixResult(filesFixed: Array(filesFixed), violationsFixed: totalFixed)
    }

    private func collectFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            throw ValidationError.directoryNotAccessible(directory)
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard FileFilters.shouldValidate(fileURL) else { continue }
            files.append(fileURL)
        }

        return files
    }
}

public struct FixResult {
    public let filesFixed: [URL]
    public let violationsFixed: Int

    public init(filesFixed: [URL], violationsFixed: Int) {
        self.filesFixed = filesFixed
        self.violationsFixed = violationsFixed
    }
}
