import Foundation
import Testing

@testable import NavigatorApp

@Suite("WorkshopMaterialsLoader")
struct WorkshopMaterialsLoaderTests {
    @Test("loadAll reads all three manifest entries from a populated directory")
    func loadsAllThreeMaterials() throws {
        let tempRoot = try makeTempPublicDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let folder =
            tempRoot
            .appendingPathComponent("workshops")
            .appendingPathComponent("claude-code-zodiac")
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        try "# Runbook body".write(
            to: folder.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# OA body".write(
            to: folder.appendingPathComponent("operating-agreement.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# Personas body".write(
            to: folder.appendingPathComponent("personas.md"),
            atomically: true,
            encoding: .utf8
        )

        let materials = try WorkshopMaterialsLoader.loadAll(publicDirectory: tempRoot.path)

        #expect(materials.count == 3)
        #expect(materials.map(\.slug) == ["readme", "operating-agreement", "personas"])

        let readme = try #require(materials.first)
        #expect(readme.rawMarkdown == "# Runbook body")
        #expect(readme.rawURL == "/workshops/claude-code-zodiac/README.md")
        #expect(readme.title == "Participant runbook")
    }

    @Test("loadAll silently skips missing files so a partial install still boots")
    func skipsMissingFiles() throws {
        let tempRoot = try makeTempPublicDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let folder =
            tempRoot
            .appendingPathComponent("workshops")
            .appendingPathComponent("claude-code-zodiac")
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        // Only the personas file exists — the other two manifest entries are missing.
        try "# Personas body".write(
            to: folder.appendingPathComponent("personas.md"),
            atomically: true,
            encoding: .utf8
        )

        let materials = try WorkshopMaterialsLoader.loadAll(publicDirectory: tempRoot.path)

        #expect(materials.count == 1)
        #expect(materials.first?.slug == "personas")
    }

    @Test("loadAll on an empty directory returns an empty array without throwing")
    func emptyDirectoryReturnsEmpty() throws {
        let tempRoot = try makeTempPublicDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let materials = try WorkshopMaterialsLoader.loadAll(publicDirectory: tempRoot.path)
        #expect(materials.isEmpty)
    }

    private func makeTempPublicDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("nlfweb-loader-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
        return base
    }
}
