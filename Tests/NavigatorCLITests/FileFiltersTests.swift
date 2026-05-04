import Foundation
import Testing

@testable import NavigatorCLI

@Suite("FileFilters")
struct FileFiltersTests {
    private func url(_ path: String) -> URL {
        URL(fileURLWithPath: "/repo/" + path)
    }

    @Test("README.md is excluded")
    func testReadmeExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("README.md")))
    }

    @Test("CLAUDE.md is excluded")
    func testClaudeExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("CLAUDE.md")))
    }

    @Test("CODE_OF_CONDUCT.md is excluded")
    func testCodeOfConductExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("CODE_OF_CONDUCT.md")))
    }

    @Test("LICENSE.md is excluded")
    func testLicenseExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("LICENSE.md")))
    }

    @Test("ERD.md is excluded (generated docs)")
    func testErdExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("Sources/NavigatorDAL/ERD.md")))
    }

    @Test("Files under ClaudeTemplates/ are excluded")
    func testClaudeTemplatesExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("ClaudeTemplates/agents/markdown-formatter.md")))
        #expect(FileFilters.shouldExcludeFromValidation(url("ClaudeTemplates/commands/format-markdown.md")))
    }

    @Test("Files under Public/workshops/ are excluded")
    func testWorkshopsExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("Public/workshops/claude-code-zodiac/personas.md")))
        #expect(
            FileFilters.shouldExcludeFromValidation(url("Public/workshops/claude-code-zodiac/operating-agreement.md"))
        )
    }

    @Test("Files under Sources/App/Content/Blog/ are excluded")
    func testBlogExcluded() {
        #expect(FileFilters.shouldExcludeFromValidation(url("Sources/App/Content/Blog/hello-world.md")))
        #expect(FileFilters.shouldExcludeFromValidation(url("Sources/App/Content/Blog/harness-is-now-navigator.md")))
    }

    @Test("Regular markdown files are not excluded")
    func testRegularFilesIncluded() {
        #expect(!FileFilters.shouldExcludeFromValidation(url("Sources/Foo/Bar.md")))
        #expect(!FileFilters.shouldExcludeFromValidation(url("docs/Architecture.md")))
    }

    @Test("shouldValidate returns false for non-markdown files")
    func testNonMarkdownNotValidated() {
        #expect(!FileFilters.shouldValidate(url("Sources/Foo.swift")))
    }

    @Test("shouldValidate returns true for regular markdown files")
    func testMarkdownValidated() {
        #expect(FileFilters.shouldValidate(url("docs/Architecture.md")))
    }

    @Test("shouldValidate returns false for excluded markdown files")
    func testExcludedMarkdownNotValidated() {
        #expect(!FileFilters.shouldValidate(url("README.md")))
        #expect(!FileFilters.shouldValidate(url("ClaudeTemplates/agents/markdown-formatter.md")))
    }
}
