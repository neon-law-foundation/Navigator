import Foundation
import Testing

@testable import NavigatorCLI

@Suite("NotationCommand")
struct NotationCommandTests {

    // MARK: - codeFromFileURL

    @Test("Derives code from Examples subdirectory path")
    func testCodeFromExamplesSubdirectoryPath() {
        let url = URL(fileURLWithPath: "~/Trifecta/NLF/Navigator/Sources/NavigatorDAL/Examples/Trusts/nevada.md")
        #expect(NotationCommand.codeFromFileURL(url) == "trusts__nevada")
    }

    @Test("Derives code from top-level Examples file")
    func testCodeFromTopLevelExamplesFile() {
        let url = URL(fileURLWithPath: "/some/path/Examples/simple.md")
        #expect(NotationCommand.codeFromFileURL(url) == "simple")
    }

    @Test("Falls back to filename stem when no Examples component")
    func testCodeFallsBackToFilenameStem() {
        let url = URL(fileURLWithPath: "/some/other/path/my-template.md")
        #expect(NotationCommand.codeFromFileURL(url) == "my-template")
    }

    @Test("Handles deeply nested Examples path")
    func testCodeFromDeeplyNestedExamplesPath() {
        let url = URL(fileURLWithPath: "/root/Examples/Category/Sub/doc.md")
        #expect(NotationCommand.codeFromFileURL(url) == "category__sub__doc")
    }
}
