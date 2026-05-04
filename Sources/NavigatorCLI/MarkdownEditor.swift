import Foundation

enum MarkdownEditor {
    /// Parses a markdown string into front matter and content
    /// - Parameter markdown: The full markdown string
    /// - Returns: A tuple of (frontMatter, content) where frontMatter is nil if none exists
    static func parseFrontMatter(from markdown: String) throws -> (frontMatter: String?, content: String) {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard lines.count > 0, lines[0] == "---" else {
            return (nil, markdown)
        }

        guard let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            return (nil, markdown)
        }

        let frontMatterLines = Array(lines[0...endIndex])
        let contentLines = Array(lines.dropFirst(endIndex + 1))

        let frontMatter = frontMatterLines.joined(separator: "\n")
        let content = contentLines.joined(separator: "\n")

        return (frontMatter, content)
    }

    /// Transforms markdown for editing by joining lines within paragraphs
    /// - Parameter markdown: The markdown content (without front matter)
    /// - Returns: Transformed markdown with long lines
    static func transformForEditing(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []
        var currentBlock: [String] = []
        var inCodeBlock = false
        var codeBlockLines: [String] = []

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    codeBlockLines.append(line)
                    result.append(contentsOf: codeBlockLines)
                    codeBlockLines = []
                    inCodeBlock = false
                } else {
                    flushCurrentBlock(&result, &currentBlock)
                    codeBlockLines.append(line)
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }

            if line.isEmpty {
                flushCurrentBlock(&result, &currentBlock)
                result.append("")
                continue
            }

            if isHeader(line) {
                flushCurrentBlock(&result, &currentBlock)
                result.append(line)
                continue
            }

            if isListItem(line) {
                flushCurrentBlock(&result, &currentBlock)
                currentBlock.append(line)
                continue
            }

            if let lastItem = currentBlock.last, isListItem(lastItem) {
                currentBlock[currentBlock.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
                continue
            }

            if currentBlock.isEmpty {
                currentBlock.append(line)
            } else {
                currentBlock[currentBlock.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
            }
        }

        flushCurrentBlock(&result, &currentBlock)

        return result.joined(separator: "\n")
    }

    /// Generates the temp file path for a given file
    /// - Parameter filePath: Original file path
    /// - Returns: Path in ~/.navigator/temp/ directory with .pages extension
    static func tempPath(for filePath: String) -> String {
        let url = URL(fileURLWithPath: filePath)
        let filenameWithoutExtension = url.deletingPathExtension().lastPathComponent
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.navigator/temp/\(filenameWithoutExtension).pages"
    }

    /// Ensures the temp directory exists
    /// - Returns: The path to the temp directory
    static func ensureTempDirectory() throws -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let tempDir = "\(homeDir)/.navigator/temp"

        if !FileManager.default.fileExists(atPath: tempDir) {
            try FileManager.default.createDirectory(
                atPath: tempDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return tempDir
    }

    private static func isHeader(_ line: String) -> Bool {
        line.hasPrefix("#")
    }

    private static func isListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return true
        }

        let numberPattern = /^\d+\.\s/
        return trimmed.firstMatch(of: numberPattern) != nil
    }

    private static func getIndentation(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }

    private static func flushCurrentBlock(_ result: inout [String], _ currentBlock: inout [String]) {
        if !currentBlock.isEmpty {
            result.append(contentsOf: currentBlock)
            currentBlock = []
        }
    }
}
