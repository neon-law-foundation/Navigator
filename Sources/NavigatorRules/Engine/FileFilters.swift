import Foundation

/// Shared file filtering logic for validators
public enum FileFilters {
    /// Default filenames excluded from validation when no override is supplied.
    ///
    /// Exposed so callers (and downstream tools) can introspect what the default
    /// exclusion list contains without having to read the source.
    public static let defaultExcludedFilenames: Set<String> = [
        "README.md",
        "CLAUDE.md",
        "CODE_OF_CONDUCT.md",
        "LICENSE.md",
        "ERD.md",
    ]

    /// Default directory names whose descendants are excluded from validation.
    public static let defaultExcludedDirectories: Set<String> = [
        "AgentDocumentation",
        "workshops",
        "Blog",
    ]

    /// Determines if a file should be excluded from validation
    /// - Parameters:
    ///   - url: The file URL to check
    ///   - excludedFilenames: Filenames to exclude. Defaults to
    ///     ``defaultExcludedFilenames``.
    ///   - excludedDirectories: Directory names whose descendants should be
    ///     excluded. Defaults to ``defaultExcludedDirectories``.
    /// - Returns: `true` if the file should be excluded, `false` otherwise.
    public static func shouldExcludeFromValidation(
        _ url: URL,
        excludedFilenames: Set<String> = defaultExcludedFilenames,
        excludedDirectories: Set<String> = defaultExcludedDirectories
    ) -> Bool {
        if excludedFilenames.contains(url.lastPathComponent) {
            return true
        }
        return !excludedDirectories.isDisjoint(with: url.pathComponents)
    }

    /// Determines if a file is a Markdown file that should be validated
    /// - Parameters:
    ///   - url: The file URL to check
    ///   - excludedFilenames: Filenames to exclude. Defaults to
    ///     ``defaultExcludedFilenames``.
    ///   - excludedDirectories: Directory names whose descendants should be
    ///     excluded. Defaults to ``defaultExcludedDirectories``.
    /// - Returns: `true` if the file is a Markdown file and should be validated.
    public static func shouldValidate(
        _ url: URL,
        excludedFilenames: Set<String> = defaultExcludedFilenames,
        excludedDirectories: Set<String> = defaultExcludedDirectories
    ) -> Bool {
        url.pathExtension == "md"
            && !shouldExcludeFromValidation(
                url,
                excludedFilenames: excludedFilenames,
                excludedDirectories: excludedDirectories
            )
    }
}
