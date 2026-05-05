import Foundation
import Yams

/// F106: workflow must include 'staff_review' as a state
public struct F106_StaffReviewRequired: Rule {
    public let code = "F106"
    public let description = "workflow must include 'staff_review' as a state"
    private let parser = FrontmatterParser()

    public init() {}

    public func validate(file: URL) throws -> [Violation] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ValidationError.fileNotFound(file)
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        guard parser.hasFrontmatter(content) else {
            return []
        }

        let rawFrontmatter = extractRawFrontmatter(from: content)

        struct FM: Decodable {
            let workflow: [String: [String: String]]?
        }

        let fm: FM
        do {
            fm = try YAMLDecoder().decode(FM.self, from: rawFrontmatter)
        } catch {
            return []
        }

        guard let workflow = fm.workflow else {
            return []
        }

        if workflow.keys.contains("staff_review") {
            return []
        }

        return [
            Violation(
                ruleCode: code,
                message: "workflow is missing required 'staff_review' state"
            )
        ]
    }

    private func extractRawFrontmatter(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first == "---" else { return "" }

        var endIndex: Int?
        for (index, line) in lines.enumerated() where index > 0 {
            if line == "---" {
                endIndex = index
                break
            }
        }

        guard let end = endIndex else { return "" }
        return lines[1..<end].joined(separator: "\n")
    }
}
