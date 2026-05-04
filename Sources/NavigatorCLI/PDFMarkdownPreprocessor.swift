import Foundation

struct PDFMarkdownPreprocessor {
    private static let horizontalRulePattern = try! NSRegularExpression(
        pattern: #"^\s*-{3,}\s*$"#
    )
    private static let signaturePattern = try! NSRegularExpression(
        pattern: #"\{[^}]+\.signature\}"#
    )

    func preprocess(_ input: String) -> String {
        let lines = input.components(separatedBy: "\n")
        var insideCodeBlock = false
        var result: [String] = []

        for line in lines {
            if line.hasPrefix("```") {
                insideCodeBlock.toggle()
                result.append(line)
                continue
            }

            if insideCodeBlock {
                result.append(line)
                continue
            }

            let range = NSRange(line.startIndex..., in: line)
            if Self.horizontalRulePattern.firstMatch(in: line, range: range) != nil {
                result.append("")
                result.append("\\newpage")
                result.append("")
            } else {
                let replaced = Self.signaturePattern.stringByReplacingMatches(
                    in: line,
                    range: range,
                    withTemplate: "__________________"
                )
                result.append(replaced)
            }
        }

        return result.joined(separator: "\n")
    }
}
