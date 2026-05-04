import Foundation
import NavigatorDAL
import NavigatorRules
import Testing

@Suite("TemplateValidator")
struct TemplateValidatorTests {
    let validator = TemplateValidator()

    @Test("Valid template passes validation")
    func testValidTemplate() {
        let validations = validator.validate(
            title: "Test Template",
            description: "A test template",
            respondentType: "person",
            frontmatter: [
                "title": "Test Template",
                "description": "A test template",
                "respondent_type": "person",
            ],
            markdownContent: "# Test\n\nContent here."
        )

        #expect(validations.isEmpty)
    }

    @Test("Empty title fails validation")
    func testEmptyTitle() {
        let validations = validator.validate(
            title: "",
            description: "A test template",
            respondentType: "person",
            frontmatter: [
                "title": "",
                "description": "A test template",
                "respondent_type": "person",
            ],
            markdownContent: "# Test"
        )

        #expect(validations.count == 1)
        #expect(validations[0].violation.ruleCode == "F101")
        #expect(validations[0].field == "title")
    }

    @Test("Whitespace-only title fails validation")
    func testWhitespaceTitle() {
        let validations = validator.validate(
            title: "   ",
            description: "A test template",
            respondentType: "person",
            frontmatter: [
                "title": "   ",
                "description": "A test template",
                "respondent_type": "person",
            ],
            markdownContent: "# Test"
        )

        #expect(validations.count == 1)
        #expect(validations[0].violation.ruleCode == "F101")
    }

    @Test("Invalid respondent type fails validation")
    func testInvalidRespondentType() {
        let validations = validator.validate(
            title: "Test Template",
            description: "A test template",
            respondentType: "invalid",
            frontmatter: [
                "title": "Test Template",
                "description": "A test template",
                "respondent_type": "invalid",
            ],
            markdownContent: "# Test"
        )

        #expect(validations.count == 1)
        #expect(validations[0].violation.ruleCode == "F102")
        #expect(validations[0].field == "respondent_type")
        #expect(validations[0].violation.message.contains("invalid"))
    }

    @Test("Valid respondent types all pass")
    func testValidRespondentTypes() {
        let validTypes = ["person", "entity", "person_and_entity"]

        for validType in validTypes {
            let validations = validator.validate(
                title: "Test Template",
                description: "A test template",
                respondentType: validType,
                frontmatter: [
                    "title": "Test Template",
                    "description": "A test template",
                    "respondent_type": validType,
                ],
                markdownContent: "# Test"
            )

            #expect(validations.isEmpty, "'\(validType)' should be valid")
        }
    }

    @Test("Multiple validation failures are reported")
    func testMultipleFailures() {
        let validations = validator.validate(
            title: "",
            description: "A test template",
            respondentType: "bad_type",
            frontmatter: [
                "title": "",
                "description": "A test template",
                "respondent_type": "bad_type",
            ],
            markdownContent: "# Test"
        )

        #expect(validations.count == 2)

        let ruleCodes = validations.map { $0.violation.ruleCode }.sorted()
        #expect(ruleCodes == ["F101", "F102"])
    }
}
