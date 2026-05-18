import Foundation
import NavigatorDAL
import NavigatorRules
import Testing

@Suite("TemplateValidator")
struct TemplateValidatorTests {
    let validator = TemplateValidator()

    private func makeFrontmatter(
        title: String = "Test Template",
        respondentType: RespondentType = .person,
        description: String? = "A test template"
    ) -> Frontmatter {
        Frontmatter(
            title: title,
            respondentType: respondentType,
            code: "test_template",
            confidential: false,
            description: description
        )
    }

    @Test("Valid frontmatter passes validation")
    func testValidFrontmatter() {
        let validations = validator.validate(makeFrontmatter())
        #expect(validations.isEmpty)
    }

    @Test("Empty title fails validation")
    func testEmptyTitle() {
        let validations = validator.validate(makeFrontmatter(title: ""))
        #expect(validations.count == 1)
        #expect(validations[0].violation.ruleCode == "F101")
        #expect(validations[0].field == "title")
    }

    @Test("Whitespace-only title fails validation")
    func testWhitespaceTitle() {
        let validations = validator.validate(makeFrontmatter(title: "   "))
        #expect(validations.count == 1)
        #expect(validations[0].violation.ruleCode == "F101")
    }

    @Test("All respondent types pass validation")
    func testAllRespondentTypesPass() {
        for type in RespondentType.allCases {
            let validations = validator.validate(makeFrontmatter(respondentType: type))
            #expect(validations.isEmpty, "'\(type.rawValue)' should be valid")
        }
    }
}
