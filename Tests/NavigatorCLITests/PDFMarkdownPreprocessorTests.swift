import Foundation
import Testing

@testable import NavigatorCLI

@Suite("PDF Markdown Preprocessor")
struct PDFMarkdownPreprocessorTests {
    let preprocessor = PDFMarkdownPreprocessor()

    @Test("Lone --- line becomes \\newpage")
    func testHorizontalRuleBecomesPageBreak() {
        let input = "Hello\n---\nWorld"
        let output = preprocessor.preprocess(input)
        #expect(output == "Hello\n\n\\newpage\n\nWorld")
    }

    @Test("Multiple --- lines become multiple \\newpage")
    func testMultipleHorizontalRules() {
        let input = "A\n---\n---\nB"
        let output = preprocessor.preprocess(input)
        #expect(output == "A\n\n\\newpage\n\n\n\\newpage\n\nB")
    }

    @Test("--- inside heading line is not replaced")
    func testHRInsideHeadingUnchanged() {
        let input = "## Section ---"
        let output = preprocessor.preprocess(input)
        #expect(output == "## Section ---")
    }

    @Test("{client.signature} becomes 18 underscores")
    func testClientSignatureReplaced() {
        let input = "Sign here: {client.signature}"
        let output = preprocessor.preprocess(input)
        #expect(output == "Sign here: __________________")
    }

    @Test("{notary.signature} becomes 18 underscores")
    func testNotarySignatureReplaced() {
        let input = "{notary.signature}"
        let output = preprocessor.preprocess(input)
        #expect(output == "__________________")
    }

    @Test("Multiple .signature on one line each replaced")
    func testMultipleSignaturesOnOneLine() {
        let input = "{a.signature} and {b.signature}"
        let output = preprocessor.preprocess(input)
        #expect(output == "__________________ and __________________")
    }

    @Test("{client.name} without .signature is unchanged")
    func testNonSignatureCurlyUnchanged() {
        let input = "{client.name}"
        let output = preprocessor.preprocess(input)
        #expect(output == "{client.name}")
    }

    @Test("--- at start of content emits leading blank line")
    func testHorizontalRuleAtStart() {
        let input = "---\nContent"
        #expect(preprocessor.preprocess(input) == "\n\\newpage\n\nContent")
    }

    @Test("--- at end of content emits trailing blank line")
    func testHorizontalRuleAtEnd() {
        let input = "Content\n---"
        #expect(preprocessor.preprocess(input) == "Content\n\n\\newpage\n")
    }

    @Test("--- with surrounding whitespace still emits blank-line-wrapped \\newpage")
    func testHorizontalRuleWithWhitespace() {
        let input = "Hello\n  ---  \nWorld"
        #expect(preprocessor.preprocess(input) == "Hello\n\n\\newpage\n\nWorld")
    }

    @Test("--- inside language-tagged code block is not replaced")
    func testHRInsideLanguageTaggedCodeBlockUnchanged() {
        let input = "```swift\n---\n```"
        #expect(preprocessor.preprocess(input) == "```swift\n---\n```")
    }

    @Test("--- inside code block is not replaced")
    func testHRInsideCodeBlockUnchanged() {
        let input = "```\n---\n```"
        let output = preprocessor.preprocess(input)
        #expect(output == "```\n---\n```")
    }

    @Test("Both rules applied together in one pass")
    func testBothRulesApplied() {
        let input = "---\n{x.signature}"
        let output = preprocessor.preprocess(input)
        #expect(output == "\n\\newpage\n\n__________________")
    }
}
