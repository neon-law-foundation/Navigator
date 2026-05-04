import Foundation

/// F103: Markdown filenames must use PascalCase
public struct F103_PascalCaseFilename: Rule {
    public let code = "F103"
    public let description = "Markdown filenames must use PascalCase (e.g., MyDocument.md)"

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let filename = file.deletingPathExtension().lastPathComponent

        guard !isPascalCase(filename) else {
            return []
        }

        let suggestedName = convertToPascalCase(filename)

        return [
            Violation(
                ruleCode: code,
                message:
                    "Filename '\(filename)' is not PascalCase. Rename to '\(suggestedName).md'",
                context: [
                    "current": filename,
                    "suggested": suggestedName,
                    "pattern": "PascalCase starts with uppercase, each word capitalized, no separators",
                ]
            )
        ]
    }

    /// Check if a string follows PascalCase conventions
    private func isPascalCase(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }

        // Must start with uppercase letter
        guard let first = name.first, first.isUppercase, first.isLetter else {
            return false
        }

        // Must not contain separators (underscores, hyphens, spaces)
        let separators = CharacterSet(charactersIn: "_- ")
        guard name.rangeOfCharacter(from: separators) == nil else {
            return false
        }

        // Must only contain letters and numbers
        let allowedCharacters = CharacterSet.alphanumerics
        guard name.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return false
        }

        return true
    }

    /// Convert a string to PascalCase
    private func convertToPascalCase(_ name: String) -> String {
        // Split by common separators
        let separators = CharacterSet(charactersIn: "_- ")
        let words = name.components(separatedBy: separators)

        // Capitalize each word and join
        return
            words
            .filter { !$0.isEmpty }
            .map { word in
                // If word is all caps, lowercase it first then capitalize
                let processed = word.allSatisfy({ $0.isUppercase }) ? word.lowercased() : word
                return processed.prefix(1).uppercased() + processed.dropFirst()
            }
            .joined()
    }
}
