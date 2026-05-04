import Foundation
import Testing

@testable import NavigatorCLI

@Suite("PDF Command")
struct PDFCommandTests {

    private func makeTestDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "pdf-test-\(UUID())"
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func validNotationContent(body: String = "# Section\n\nSome content.") -> String {
        """
        ---
        title: Test Notation
        respondent_type: person
        confidential: false
        ---

        \(body)
        """
    }

    @Test("Generates PDF from valid notation")
    func testGeneratesPDFFromValidNotation() async throws {
        guard PandocConverter.isPandocInstalled() else { return }

        let testDir = try makeTestDir()
        let testFile = testDir.appendingPathComponent("TestNotation.md")
        try validNotationContent().write(to: testFile, atomically: true, encoding: .utf8)

        let command = PDFCommand(inputPath: testFile.path)
        try await command.run()

        let outputURL = testFile.deletingPathExtension().appendingPathExtension("pdf")
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("Notation with --- page break produces multi-page PDF")
    func testPageBreakProducesMultiplePDFPages() async throws {
        guard PandocConverter.isPandocInstalled() else { return }

        let pdftk = ["/opt/homebrew/bin/pdftk", "/usr/local/bin/pdftk", "/usr/bin/pdftk"]
            .first { FileManager.default.fileExists(atPath: $0) }
        guard let pdftkPath = pdftk else { return }

        let testDir = try makeTestDir()
        let testFile = testDir.appendingPathComponent("TestPageBreak.md")
        let body = "# Page One\n\nContent on page one.\n\n---\n\n# Page Two\n\nContent on page two."
        try validNotationContent(body: body).write(to: testFile, atomically: true, encoding: .utf8)

        let command = PDFCommand(inputPath: testFile.path)
        try await command.run()

        let outputURL = testFile.deletingPathExtension().appendingPathExtension("pdf")
        let pageCount = countPDFPages(at: outputURL, pdftkPath: pdftkPath)
        #expect(pageCount >= 2)

        try? FileManager.default.removeItem(at: testDir)
    }

    @Test("Throws on missing file")
    func testThrowsOnMissingFile() async throws {
        let command = PDFCommand(inputPath: "/tmp/nonexistent-\(UUID()).md")
        await #expect(throws: CommandError.self) {
            try await command.run()
        }
    }

    @Test("Throws on notation that fails lint validation")
    func testThrowsOnLintFailure() async throws {
        let testDir = try makeTestDir()
        let testFile = testDir.appendingPathComponent("invalid.md")
        try "# No frontmatter here\n\nJust content.\n".write(
            to: testFile,
            atomically: true,
            encoding: .utf8
        )

        let command = PDFCommand(inputPath: testFile.path)
        await #expect(throws: CommandError.self) {
            try await command.run()
        }

        try? FileManager.default.removeItem(at: testDir)
    }

    private func countPDFPages(at url: URL, pdftkPath: String) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pdftkPath)
        process.arguments = [url.path, "dump_data"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            for line in output.components(separatedBy: "\n") {
                if line.hasPrefix("NumberOfPages:") {
                    return Int(
                        line.components(separatedBy: ":").last?
                            .trimmingCharacters(in: .whitespaces) ?? ""
                    ) ?? 0
                }
            }
        } catch {}
        return 0
    }
}
