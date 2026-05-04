import Foundation

enum PandocConverter {
    /// Finds the pandoc executable by searching PATH
    private static func pandocURL() -> URL? {
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let isWindows = ProcessInfo.processInfo.environment["OS"]?.contains("Windows") == true
        let separator: Character = isWindows ? ";" : ":"
        let execName = isWindows ? "pandoc.exe" : "pandoc"
        for dir in pathEnv.split(separator: separator) {
            let url = URL(fileURLWithPath: String(dir)).appendingPathComponent(execName)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// Checks if pandoc is installed and available
    static func isPandocInstalled() -> Bool {
        guard let url = pandocURL() else { return false }
        let process = Process()
        process.executableURL = url
        process.arguments = ["--version"]

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Converts markdown to DOCX using pandoc
    /// - Parameters:
    ///   - markdownContent: The markdown content to convert
    ///   - outputPath: The path where the DOCX file should be saved
    /// - Throws: CommandError if pandoc fails
    static func convertMarkdownToDOCX(markdown: String, outputPath: String) throws {
        let tempInputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("pandoc-input-\(UUID()).md").path
        try markdown.write(toFile: tempInputFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: tempInputFile)
        }

        guard let pandoc = pandocURL() else {
            throw CommandError.setupFailed(
                "pandoc is not installed. Install it with: brew install pandoc"
            )
        }
        let process = Process()
        process.executableURL = pandoc
        process.arguments = [
            tempInputFile,
            "-f", "markdown",
            "-t", "docx",
            "-o", outputPath,
            "--standalone",
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CommandError.setupFailed("pandoc conversion to DOCX failed: \(errorMessage)")
        }
    }

    /// Converts DOCX to markdown using pandoc
    /// - Parameter docxPath: The path to the DOCX file
    /// - Returns: The converted markdown content with 120 character line wrapping and page breaks as empty lines
    /// - Throws: CommandError if pandoc fails
    static func convertDOCXToMarkdown(docxPath: String) throws -> String {
        guard let pandoc = pandocURL() else {
            throw CommandError.setupFailed(
                "pandoc is not installed. Install it with: brew install pandoc"
            )
        }

        guard FileManager.default.fileExists(atPath: docxPath) else {
            throw CommandError.fileNotFound(docxPath)
        }

        let process = Process()
        process.executableURL = pandoc
        process.arguments = [
            docxPath,
            "-f", "docx",
            "-t", "markdown",
            "--columns=120",
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CommandError.setupFailed("pandoc conversion from DOCX failed: \(errorMessage)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard var markdown = String(data: outputData, encoding: .utf8) else {
            throw CommandError.setupFailed("Failed to decode pandoc output")
        }

        markdown = processPageBreaks(markdown)
        markdown = restoreDemotedHeaders(markdown)
        markdown = restoreDemotedLists(markdown)
        markdown = trimTrailingWhitespace(markdown)

        return markdown
    }

    /// Converts a DOCX file to Pages format using AppleScript
    /// - Parameters:
    ///   - docxPath: Path to the DOCX file
    ///   - pagesPath: Path where the Pages file should be saved
    /// - Throws: CommandError if conversion fails
    static func convertDOCXToPages(docxPath: String, pagesPath: String) throws {
        guard FileManager.default.fileExists(atPath: docxPath) else {
            throw CommandError.fileNotFound(docxPath)
        }

        let script = """
            tell application "Pages"
                set theDoc to open POSIX file "\(docxPath)"
                save theDoc in POSIX file "\(pagesPath)"
                close theDoc saving no
            end tell
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CommandError.setupFailed("Failed to convert DOCX to Pages: \(errorMessage)")
        }
    }

    /// Converts a Pages file to DOCX format using AppleScript
    /// - Parameters:
    ///   - pagesPath: Path to the Pages file
    ///   - docxPath: Path where the DOCX file should be saved
    /// - Throws: CommandError if conversion fails
    static func convertPagesToDOCX(pagesPath: String, docxPath: String) throws {
        guard FileManager.default.fileExists(atPath: pagesPath) else {
            throw CommandError.fileNotFound(pagesPath)
        }

        let script = """
            tell application "Pages"
                set theDoc to open POSIX file "\(pagesPath)"
                export theDoc to file (POSIX file "\(docxPath)") as Microsoft Word
                close theDoc saving no
            end tell
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CommandError.setupFailed("Failed to convert Pages to DOCX: \(errorMessage)")
        }
    }

    /// Restores first-level headers that Pages demotes to plain paragraphs
    /// When Pages exports to DOCX, it converts first-level headers to plain text.
    /// This function detects such cases and restores them as `# Header`
    private static func restoreDemotedHeaders(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard lines.count >= 2 else {
            return markdown
        }

        var result: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if i == 0 && !trimmed.isEmpty && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("---") {
                let nextIndex = i + 1
                if nextIndex < lines.count {
                    let nextLine = lines[nextIndex].trimmingCharacters(in: .whitespaces)

                    if nextLine.isEmpty || nextLine.hasPrefix("##") {
                        result.append("# " + trimmed)
                        i += 1
                        continue
                    }
                }
            }

            result.append(line)
            i += 1
        }

        return result.joined(separator: "\n")
    }

    /// Restores list formatting that Pages converts to plain text
    /// When Pages exports to DOCX, it may convert list items to plain paragraphs
    /// with bullet characters (•, ·) or numbers. This function restores proper markdown list syntax.
    /// Note: Pages often completely strips list formatting, making automatic restoration impossible.
    private static func restoreDemotedLists(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for explicit bullet characters that survived
            if trimmed.hasPrefix("• ") || trimmed.hasPrefix("· ") {
                let content = String(trimmed.dropFirst(2))
                result.append("- \(content)")
            } else if trimmed.range(of: "^[0-9]+\\. ", options: .regularExpression) != nil {
                // Numbered lists are already in proper format
                result.append(String(trimmed))
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }

    /// Trims trailing whitespace from each line in the markdown
    private static func trimTrailingWhitespace(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let trimmedLines = lines.map { line in
            line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        }
        return trimmedLines.joined(separator: "\n")
    }

    /// Process page breaks in markdown content by converting them to empty lines
    /// Handles common page break representations from DOCX conversion:
    /// - LaTeX commands: \newpage, \pagebreak
    /// - Form feed characters: \f
    /// - Raw page break markers
    private static func processPageBreaks(_ markdown: String) -> String {
        var processed = markdown

        processed = processed.replacingOccurrences(of: "\\newpage", with: "\n\n")
        processed = processed.replacingOccurrences(of: "\\pagebreak", with: "\n\n")
        processed = processed.replacingOccurrences(of: "\u{000C}", with: "\n\n")

        let lines = processed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "<!-- pagebreak -->" || trimmed == "---" && line == trimmed {
                result.append("")
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}
