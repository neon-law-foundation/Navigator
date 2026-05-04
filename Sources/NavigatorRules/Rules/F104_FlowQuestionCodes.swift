import Foundation
import Yams

/// F104: questionnaire and workflow state names must reference valid question codes
public struct F104_FlowQuestionCodes: Rule {
    public let code = "F104"
    public let description =
        "questionnaire and workflow state names must reference valid question codes"

    private let validCodes: Set<String>
    private let parser = FrontmatterParser()

    public init(validCodes: Set<String>) {
        self.validCodes = validCodes
    }

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
            let questionnaire: [String: [String: String]]?
            let workflow: [String: [String: String]]?
        }

        let fm: FM
        do {
            fm = try YAMLDecoder().decode(FM.self, from: rawFrontmatter)
        } catch {
            return []
        }

        var violations: [Violation] = []

        guard let questionnaire = fm.questionnaire else {
            violations.append(
                Violation(ruleCode: code, message: "Missing required 'questionnaire' key")
            )
            return violations
        }

        guard let workflow = fm.workflow else {
            violations.append(
                Violation(ruleCode: code, message: "Missing required 'workflow' key")
            )
            return violations
        }

        violations += validateMap(questionnaire, named: "questionnaire")
        violations += validateMap(workflow, named: "workflow")

        return violations
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

    private func validateMap(
        _ map: [String: [String: String]],
        named mapName: String
    ) -> [Violation] {
        var violations: [Violation] = []

        guard map["BEGIN"] != nil else {
            violations.append(
                Violation(
                    ruleCode: code,
                    message: "\(mapName) is missing required BEGIN state"
                )
            )
            return violations
        }

        let hasEnd = map.values.contains { transitions in
            transitions.values.contains("END")
        }
        guard hasEnd else {
            violations.append(
                Violation(
                    ruleCode: code,
                    message: "\(mapName) is missing required END state"
                )
            )
            return violations
        }

        for stateKey in map.keys where stateKey != "BEGIN" && stateKey != "END" {
            let questionCode = stateKey.components(separatedBy: "__").first ?? stateKey
            guard validCodes.contains(questionCode) else {
                violations.append(
                    Violation(
                        ruleCode: code,
                        message:
                            "Invalid question code: '\(questionCode)' (from state '\(stateKey)')"
                    )
                )
                continue
            }
        }

        return violations
    }
}
