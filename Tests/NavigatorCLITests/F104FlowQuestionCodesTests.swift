import Foundation
import NavigatorRules
import Testing

@Suite("F104 Flow Question Codes")
struct F104FlowQuestionCodesTests {
    let validCodes: Set<String> = ["personal_name", "staff_review", "notarization", "person"]

    private func makeFile(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("F104Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("TestFile.md")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    // MARK: - Pass cases

    @Test("Valid codes with labels pass")
    func testValidCodesWithLabels() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: person__trustee
              person__trustee:
                _: END
            workflow:
              BEGIN:
                _: notarization__for_trustee
              notarization__for_trustee:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    @Test("Valid codes without labels pass")
    func testValidCodesWithoutLabels() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    @Test("Both questionnaire and workflow valid pass")
    func testBothQuestionnaireAndWorkflowValid() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: personal_name
              personal_name:
                _: staff_review
              staff_review:
                _: END
            workflow:
              BEGIN:
                _: notarization__for_client
              notarization__for_client:
                yes: END
                _: person__trustee
              person__trustee:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    @Test("File with no frontmatter passes")
    func testNoFrontmatterPasses() throws {
        let content = """
            # Just a plain markdown file

            No frontmatter here.
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    // MARK: - Structural failures

    @Test("Missing questionnaire key produces violation")
    func testMissingQuestionnaireKey() throws {
        let content = """
            ---
            title: Test
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message == "Missing required 'questionnaire' key")
    }

    @Test("Missing workflow key produces violation")
    func testMissingWorkflowKey() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].message == "Missing required 'workflow' key")
    }

    @Test("questionnaire missing BEGIN produces violation")
    func testQuestionnaireMissingBegin() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              staff_review:
                _: END
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.contains { $0.message == "questionnaire is missing required BEGIN state" })
    }

    @Test("questionnaire missing END produces violation")
    func testQuestionnaireMissingEnd() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: staff_review
              staff_review:
                _: personal_name
              personal_name:
                _: staff_review
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.contains { $0.message == "questionnaire is missing required END state" })
    }

    @Test("workflow missing BEGIN produces violation")
    func testWorkflowMissingBegin() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            workflow:
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.contains { $0.message == "workflow is missing required BEGIN state" })
    }

    @Test("workflow missing END produces violation")
    func testWorkflowMissingEnd() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: personal_name
              personal_name:
                _: staff_review
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(violations.contains { $0.message == "workflow is missing required END state" })
    }

    // MARK: - Invalid codes

    @Test("Invalid code in questionnaire produces violation")
    func testInvalidCodeInQuestionnaire() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: tax_advisor
              tax_advisor:
                _: END
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(
            violations.contains {
                $0.message == "Invalid question code: 'tax_advisor' (from state 'tax_advisor')"
            }
        )
    }

    @Test("Invalid code in workflow produces violation")
    func testInvalidCodeInWorkflow() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            workflow:
              BEGIN:
                _: bad_code
              bad_code:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(
            violations.contains {
                $0.message == "Invalid question code: 'bad_code' (from state 'bad_code')"
            }
        )
    }

    @Test("Multiple invalid codes produce multiple violations")
    func testMultipleInvalidCodesProduceMultipleViolations() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: tax_advisor
              tax_advisor:
                _: bad_code
              bad_code:
                _: END
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        let invalidViolations = violations.filter { $0.message.hasPrefix("Invalid question code") }
        #expect(invalidViolations.count == 2)
    }

    @Test("Invalid code with label emits state name in context")
    func testInvalidCodeWithLabelEmitsStateName() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: tax_advisor__for_client
              tax_advisor__for_client:
                _: END
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        #expect(
            violations.contains {
                $0.message
                    == "Invalid question code: 'tax_advisor' (from state 'tax_advisor__for_client')"
            }
        )
    }

    @Test("Valid and invalid codes mixed — only invalid flagged")
    func testMixedCodesOnlyInvalidFlagged() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: staff_review
              staff_review:
                _: bad_code
              bad_code:
                _: END
            workflow:
              BEGIN:
                _: notarization
              notarization:
                _: END
            ---
            """
        let file = try makeFile(content: content)
        let rule = F104_FlowQuestionCodes(validCodes: validCodes)
        let violations = try rule.validate(file: file)
        let invalidViolations = violations.filter { $0.message.hasPrefix("Invalid question code") }
        #expect(invalidViolations.count == 1)
        #expect(
            invalidViolations[0].message
                == "Invalid question code: 'bad_code' (from state 'bad_code')"
        )
    }
}
