import Foundation

struct FormatCommand: Command {
    let filePath: String

    func run() async throws {
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CommandError.setupFailed("File not found: \(filePath)")
        }

        print("Formatting \(filePath)...")
        print("")

        let content = try String(contentsOf: fileURL, encoding: .utf8)

        let (frontMatter, markdownContent) = try MarkdownEditor.parseFrontMatter(from: content)

        var formatted = markdownContent

        print("→ Wrapping lines at 120 characters")
        formatted = try wrapLines(formatted)

        print("→ Converting bullet lists from '-' to '*'")
        formatted = convertBulletListMarkers(formatted)

        print("→ Trimming trailing whitespace")
        formatted = trimTrailingWhitespace(formatted)

        var finalContent: String
        if let frontMatter = frontMatter {
            print("→ Preserving front matter")
            finalContent = frontMatter + "\n" + formatted
        } else {
            finalContent = formatted
        }

        print("")
        print("→ Writing formatted content to \(filePath)")
        try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)

        print("")
        print("✓ Formatted \(filePath)")
    }

    private func convertBulletListMarkers(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- ") {
                let content = String(trimmed.dropFirst(2))
                let indent = line.prefix(while: { $0.isWhitespace })
                result.append("\(indent)* \(content)")
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }

    private func wrapLines(_ markdown: String) throws -> String {
        guard PandocConverter.isPandocInstalled() else {
            throw CommandError.setupFailed(
                "pandoc is not installed. Install it with: brew install pandoc"
            )
        }

        let tempInputFile = "/tmp/format-input-\(UUID()).md"
        let tempOutputFile = "/tmp/format-output-\(UUID()).md"

        try markdown.write(toFile: tempInputFile, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "pandoc",
            tempInputFile,
            "-f", "markdown",
            "-t", "markdown",
            "--columns=120",
            "-o", tempOutputFile,
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        try? FileManager.default.removeItem(atPath: tempInputFile)

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            try? FileManager.default.removeItem(atPath: tempOutputFile)
            throw CommandError.setupFailed("pandoc formatting failed: \(errorMessage)")
        }

        let formatted = try String(contentsOf: URL(fileURLWithPath: tempOutputFile), encoding: .utf8)
        try? FileManager.default.removeItem(atPath: tempOutputFile)

        return formatted
    }

    private func trimTrailingWhitespace(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let trimmedLines = lines.map { line in
            line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        }
        return trimmedLines.joined(separator: "\n")
    }
}
