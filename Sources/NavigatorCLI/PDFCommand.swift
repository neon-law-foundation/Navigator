import Foundation
import NavigatorRules

struct PDFCommand: Command {
    let inputPath: String

    func run() async throws {
        let fileURL = URL(fileURLWithPath: inputPath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Error: File not found: \(inputPath)")
            throw CommandError.fileNotFound(inputPath)
        }

        guard fileURL.pathExtension == "md" else {
            print("Error: File must be a Markdown file (.md): \(inputPath)")
            throw CommandError.invalidFileType(inputPath)
        }

        print("📄 Validating standard: \(fileURL.lastPathComponent)")

        let s101 = S101_LineLength()
        let f101 = F101_TitleRequired()
        let f102 = F102_RespondentTypeRequired()

        let f105 = F105_ConfidentialRequired()

        let s101Violations = try s101.validate(file: fileURL)
        let f101Violations = try f101.validate(file: fileURL)
        let f102Violations = try f102.validate(file: fileURL)
        let f105Violations = try f105.validate(file: fileURL)

        let allViolations = s101Violations + f101Violations + f102Violations + f105Violations

        if !allViolations.isEmpty {
            print("✗ Validation failed:\n")

            for violation in allViolations {
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

            print("Please fix these violations before generating PDF.")
            print("Run 'navigator lint \(fileURL.path)' for more details.")
            throw CommandError.validationFailed
        }

        print("✓ Validation passed")

        let content = try String(contentsOf: fileURL, encoding: .utf8)

        var markdownContent = try stripFrontmatter(from: content)
        markdownContent = PDFMarkdownPreprocessor().preprocess(markdownContent)

        if markdownContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            markdownContent = "*This standard contains no content.*\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempMarkdownFile = tempDir.appendingPathComponent(UUID().uuidString + ".md")

        try markdownContent.write(to: tempMarkdownFile, atomically: true, encoding: .utf8)

        let outputURL = fileURL.deletingPathExtension().appendingPathExtension("pdf")

        print("📝 Converting to PDF: \(outputURL.lastPathComponent)")

        try await convertToPDF(markdownFile: tempMarkdownFile, outputURL: outputURL)

        try? FileManager.default.removeItem(at: tempMarkdownFile)

        print("✅ PDF created: \(outputURL.path)")
    }

    private func stripFrontmatter(from content: String) throws -> String {
        guard content.hasPrefix("---") else {
            throw CommandError.invalidFrontmatter("Missing frontmatter delimiter")
        }

        let lines = content.components(separatedBy: .newlines)
        guard lines.first == "---" else {
            throw CommandError.invalidFrontmatter("Invalid frontmatter start")
        }

        var frontmatterEndIndex: Int?
        for (index, line) in lines.enumerated() where index > 0 {
            if line == "---" {
                frontmatterEndIndex = index
                break
            }
        }

        guard let endIndex = frontmatterEndIndex else {
            throw CommandError.invalidFrontmatter("Missing frontmatter closing delimiter")
        }

        let markdownLines = Array(lines[(endIndex + 1)...])
        return markdownLines.joined(separator: "\n")
    }

    private func convertToPDF(markdownFile: URL, outputURL: URL) async throws {
        let pandocPaths = [
            "/opt/homebrew/bin/pandoc",
            "/usr/local/bin/pandoc",
            "/usr/bin/pandoc",
        ]

        guard let pandocPath = pandocPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw CommandError.pandocNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pandocPath)
        process.arguments = [
            markdownFile.path,
            "-o", outputURL.path,
            "--from=markdown+raw_tex",
            "--to=pdf",
            "--pdf-engine=xelatex",
            "-V", "geometry:margin=1in",
            "-V", "papersize=letter",
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw CommandError.pdfGenerationFailed(
                "Failed to convert \(markdownFile.lastPathComponent) to PDF: \(output)"
            )
        }
    }
}

extension CommandError {
    static func fileNotFound(_ path: String) -> CommandError {
        .setupFailed("File not found: \(path)")
    }

    static func invalidFileType(_ path: String) -> CommandError {
        .setupFailed("Invalid file type: \(path)")
    }

    static var validationFailed: CommandError {
        .lintFailed
    }

    static func invalidFrontmatter(_ message: String) -> CommandError {
        .setupFailed("Invalid frontmatter: \(message)")
    }

    static var pandocNotFound: CommandError {
        .setupFailed("pandoc not found. Please install pandoc: brew install pandoc (or use your package manager)")
    }

    static func pdfGenerationFailed(_ message: String) -> CommandError {
        .setupFailed("PDF generation failed: \(message)")
    }
}
