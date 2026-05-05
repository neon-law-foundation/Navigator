import Foundation
import NavigatorRules
import Testing

@Suite("F106 Staff Review Required")
struct F106StaffReviewRequiredTests {
    private func makeFile(named name: String = "TestFile.md", content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("F106Tests-\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent(name)
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    // MARK: - Pass cases

    @Test("Workflow with staff_review as state passes")
    func testWorkflowWithStaffReviewPasses() throws {
        let content = """
            ---
            title: Test
            workflow:
              BEGIN:
                _: staff_review
              staff_review:
                _: END
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F106_StaffReviewRequired()
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
        let rule = F106_StaffReviewRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    @Test("File with no workflow key passes")
    func testNoWorkflowKeyPasses() throws {
        let content = """
            ---
            title: Test
            questionnaire:
              BEGIN:
                _: END
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F106_StaffReviewRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.isEmpty)
    }

    // MARK: - Fail cases

    @Test("Workflow without staff_review produces violation")
    func testWorkflowWithoutStaffReviewFails() throws {
        let content = """
            ---
            title: Test
            workflow:
              BEGIN:
                _: notarization
              notarization:
                _: END
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F106_StaffReviewRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F106")
        #expect(violations[0].message == "workflow is missing required 'staff_review' state")
    }

    @Test("Workflow with staff_review only as transition target fails")
    func testWorkflowWithStaffReviewOnlyAsTransitionFails() throws {
        let content = """
            ---
            title: Test
            workflow:
              BEGIN:
                _: staff_review
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F106_StaffReviewRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F106")
        #expect(violations[0].message == "workflow is missing required 'staff_review' state")
    }

    @Test("Workflow with staff_review__label fails (labels not allowed)")
    func testWorkflowWithStaffReviewLabelFails() throws {
        let content = """
            ---
            title: Test
            workflow:
              BEGIN:
                _: staff_review__for_trustee
              staff_review__for_trustee:
                _: END
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F106_StaffReviewRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F106")
        #expect(violations[0].message == "workflow is missing required 'staff_review' state")
    }

    @Test("Questionnaire has staff_review but workflow does not — fails")
    func testQuestionnaireHasStaffReviewButWorkflowDoesNotFails() throws {
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
                _: notarization
              notarization:
                _: END
            ---
            Body
            """
        let file = try makeFile(content: content)
        let rule = F106_StaffReviewRequired()
        let violations = try rule.validate(file: file)
        #expect(violations.count == 1)
        #expect(violations[0].ruleCode == "F106")
        #expect(violations[0].message == "workflow is missing required 'staff_review' state")
    }
}
