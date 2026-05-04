import Foundation

struct SaveCommand: Command {
    let filePath: String

    func run() async throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/osascript") else {
            throw CommandError.platformNotSupported("save command is only available on macOS")
        }

        try Self.saveTempFile(to: filePath)

        print("✓ Saved changes from temp file back to \(filePath)")
    }

    static func saveTempFile(to originalFilePath: String) throws {
        let originalURL = URL(fileURLWithPath: originalFilePath)

        guard FileManager.default.fileExists(atPath: originalURL.path) else {
            throw CommandError.fileNotFound(originalFilePath)
        }

        let tempPagesPath = MarkdownEditor.tempPath(for: originalFilePath)

        guard FileManager.default.fileExists(atPath: tempPagesPath) else {
            throw CommandError.fileNotFound(tempPagesPath)
        }

        print("Converting edited Pages document back to markdown...")
        print("")

        let tempDOCXPath = tempPagesPath.replacingOccurrences(of: ".pages", with: ".docx")

        print("→ Converting Pages to DOCX")
        print("  Input: \(tempPagesPath)")
        print("  Output: \(tempDOCXPath)")
        try PandocConverter.convertPagesToDOCX(pagesPath: tempPagesPath, docxPath: tempDOCXPath)

        print("")
        print("→ Using pandoc to convert DOCX to markdown")
        print("  Input: \(tempDOCXPath)")

        let originalContent = try String(contentsOf: originalURL, encoding: .utf8)
        let (frontMatter, _) = try MarkdownEditor.parseFrontMatter(from: originalContent)

        let editedContent = try PandocConverter.convertDOCXToMarkdown(docxPath: tempDOCXPath)

        var finalContent: String
        if let frontMatter = frontMatter {
            print("  Restoring front matter from original file")
            finalContent = frontMatter + "\n" + editedContent
        } else {
            finalContent = editedContent
        }

        print("")
        print("→ Writing to \(originalFilePath)")
        try finalContent.write(to: originalURL, atomically: true, encoding: .utf8)

        print("")
        print("→ Cleaning up temporary files")
        try? FileManager.default.removeItem(atPath: tempPagesPath)
        try? FileManager.default.removeItem(atPath: tempDOCXPath)
    }
}
