import Foundation

struct EditCommand: Command {
    let filePath: String

    func run() async throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/osascript") else {
            throw CommandError.platformNotSupported("edit command is only available on macOS")
        }

        let tempPath = try Self.createTempFile(from: filePath)

        try openInTextEdit(tempPath)

        print("")
        print("✓ Opened in Pages")
        print("")
        print("  Edit the file and save it (⌘S)")
        print("  Then run: navigator save \(filePath)")
    }

    static func createTempFile(from filePath: String) throws -> String {
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CommandError.fileNotFound(filePath)
        }

        print("Converting markdown to editable format...")
        print("")

        _ = try MarkdownEditor.ensureTempDirectory()

        let content = try String(contentsOf: fileURL, encoding: .utf8)

        let (_, markdownContent) = try MarkdownEditor.parseFrontMatter(from: content)

        let transformedContent = MarkdownEditor.transformForEditing(markdownContent)

        let tempPagesPath = MarkdownEditor.tempPath(for: filePath)
        let tempDOCXPath = tempPagesPath.replacingOccurrences(of: ".pages", with: ".docx")

        print("→ Using pandoc to convert markdown to DOCX")
        print("  Output: \(tempDOCXPath)")
        try PandocConverter.convertMarkdownToDOCX(markdown: transformedContent, outputPath: tempDOCXPath)

        print("")
        print("→ Converting DOCX to Pages format")
        print("  Output: \(tempPagesPath)")
        try PandocConverter.convertDOCXToPages(docxPath: tempDOCXPath, pagesPath: tempPagesPath)

        try? FileManager.default.removeItem(atPath: tempDOCXPath)

        print("")
        print("→ Opening in Pages")

        return tempPagesPath
    }

    private func openInTextEdit(_ filePath: String) throws {
        let script = """
            tell application "Pages"
                open POSIX file "\(filePath)"
                activate
            end tell
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CommandError.setupFailed("Failed to open Pages: \(errorMessage)")
        }
    }
}
