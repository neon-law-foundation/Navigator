import NavigatorRules

struct JurisdictionsListCommand: Command {
    func run() async throws {
        let jurisdictions = Seeds.jurisdictions.sorted { $0.code < $1.code }

        if jurisdictions.isEmpty {
            print("No jurisdictions found.")
            return
        }

        let maxCodeLength = jurisdictions.map(\.code.count).max() ?? 4
        let codeWidth = max(maxCodeLength, 4)
        let maxNameLength = jurisdictions.map(\.name.count).max() ?? 4
        let nameWidth = max(maxNameLength, 4)

        let codeHeader = "Code".padding(toLength: codeWidth, withPad: " ", startingAt: 0)
        let nameHeader = "Name".padding(toLength: nameWidth, withPad: " ", startingAt: 0)
        print("\(codeHeader)  \(nameHeader)  Type")
        print(
            String(repeating: "-", count: codeWidth) + "  "
                + String(repeating: "-", count: nameWidth) + "  "
                + String(repeating: "-", count: 10)
        )

        for jurisdiction in jurisdictions {
            let paddedCode = jurisdiction.code.padding(
                toLength: codeWidth,
                withPad: " ",
                startingAt: 0
            )
            let paddedName = jurisdiction.name.padding(
                toLength: nameWidth,
                withPad: " ",
                startingAt: 0
            )
            print("\(paddedCode)  \(paddedName)  \(jurisdiction.jurisdictionType)")
        }
    }
}
