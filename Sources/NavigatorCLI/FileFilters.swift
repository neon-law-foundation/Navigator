import Foundation

/// Shared file filtering logic for validators
public enum FileFilters {
    private static let excludedFilenames: Set<String> = [
        "README.md",
        "CLAUDE.md",
        "CODE_OF_CONDUCT.md",
        "LICENSE.md",
        "ERD.md",
    ]

    private static let excludedDirectories: Set<String> = [
        "ClaudeTemplates",
        "workshops",
        "Blog",
    ]

    /// Determines if a file should be excluded from validation
    /// - Parameter url: The file URL to check
    /// - Returns: true if the file should be excluded, false otherwise
    public static func shouldExcludeFromValidation(_ url: URL) -> Bool {
        if excludedFilenames.contains(url.lastPathComponent) {
            return true
        }
        return !excludedDirectories.isDisjoint(with: url.pathComponents)
    }

    /// Determines if a file is a Markdown file that should be validated
    /// - Parameter url: The file URL to check
    /// - Returns: true if the file is a Markdown file and should be validated
    public static func shouldValidate(_ url: URL) -> Bool {
        url.pathExtension == "md" && !shouldExcludeFromValidation(url)
    }
}
