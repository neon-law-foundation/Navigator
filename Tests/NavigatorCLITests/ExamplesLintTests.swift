import Foundation
import NavigatorRules
import Testing

@testable import NavigatorCLI

@Suite("Examples Lint")
struct ExamplesLintTests {
    private var examplesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // NavigatorCLITests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/NavigatorDAL/Examples")
    }

    @Test("All examples pass navigator lint")
    func testExamplesPassLint() throws {
        let validCodes = Set(Seeds.questions.map(\.code))
        let engine = RuleEngine(rules: [
            S101_LineLength(),
            F101_TitleRequired(),
            F102_RespondentTypeRequired(),
            F103_PascalCaseFilename(),
            F104_FlowQuestionCodes(validCodes: validCodes),
            F105_ConfidentialRequired(),
        ])

        let result = try engine.lint(directory: examplesURL)

        if !result.isValid {
            let messages = result.fileViolations.flatMap { fv in
                fv.violations.map { v in
                    "\(fv.file.lastPathComponent): [\(v.ruleCode)] \(v.message)"
                }
            }
            Issue.record("Lint violations in examples:\n\(messages.joined(separator: "\n"))")
        }

        #expect(result.isValid)
    }

    @Test("Single .md file passes navigator lint")
    func testSingleFileLint() throws {
        let nevadaURL = examplesURL.appendingPathComponent("Trusts/Nevada.md")
        let validCodes = Set(Seeds.questions.map(\.code))
        let engine = RuleEngine(rules: [
            S101_LineLength(),
            F101_TitleRequired(),
            F102_RespondentTypeRequired(),
            F103_PascalCaseFilename(),
            F104_FlowQuestionCodes(validCodes: validCodes),
            F105_ConfidentialRequired(),
        ])

        let result = try engine.lint(file: nevadaURL)
        #expect(result.isValid)
    }

    @Test("lint(file:) skips non-.md files")
    func testLintFileSkipsNonMarkdown() throws {
        let swiftFile = URL(fileURLWithPath: #filePath)
        let engine = RuleEngine(rules: [S101_LineLength()])

        let result = try engine.lint(file: swiftFile)
        #expect(result.isValid)
        #expect(result.fileViolations.isEmpty)
    }
}
