import Foundation

let arguments = CommandLine.arguments

func printUsage() {
    print(
        """
        Usage: navigator <command> [arguments]

        Commands:
          lint <path>         Validate Markdown files — accepts a directory or a single .md file
          import <directory>  Import validated Markdown notations to database (macOS only)
                              Auto-detects git repository and commit SHA
                              Requires clean working tree (no uncommitted changes)
          pdf <file>          Convert a standard Markdown file to PDF
                              Validates the file first, strips frontmatter, and outputs to .pdf
          edit <file>         Open standard file for editing in TextEdit (macOS only)
                              Creates temp file with joined lines for easier editing
          save <file>         Save edited temp file back to original (macOS only)
                              Restores front matter and saves to original location
          format <file>       Format a Markdown file
                              Converts '-' bullet lists to '*', wraps at 120 chars, trims whitespace
          glossary [term]     Print canonical definitions for all Navigator terms
                              Pass an optional term name to look up a single definition
          ddl                 Print CREATE TABLE statements for all schema tables
          list questions      List all seeded questions with their prompts
          list jurisdictions  List all seeded jurisdictions with their types
          list templates      List all seeded notation templates with their titles
          show template <code>  Show full content of a notation template by code
          notation <template>   Create a notation interactively from a seeded template code
                              or a path to a .md file. Walks the questionnaire, prompts
                              for each question, and creates the notation with interpolated
                              content. Defaults to --person 1 (local dev identity).
          agent setup         Provision ~/Work with AGENTS.md, CLAUDE.md, and .claude/commands/review.md
                              AGENTS.md is the LLM-agnostic guidance file; CLAUDE.md is a one-line
                              pointer to AGENTS.md so Claude Code picks up the same content
                              review.md provides the /review skill: a 12-agent Lawyer Council
                              where each agent embodies a zodiac sign and legal specialty —
                              Aries (Trial), Taurus (Estate), Gemini (Transactional),
                              Cancer (Family), Leo (Constitutional), Virgo (Regulatory),
                              Libra (Mediator), Scorpio (Fraud), Sagittarius (International),
                              Capricorn (Corporate), Aquarius (Technology), Pisces (Public Interest)

        Options:
          --help, -h          Show this help message
          --version, -v       Show version information

        Examples:
          navigator lint .
          navigator lint Sources/NavigatorDAL/Examples/Trusts/nevada.md
          navigator import ./notations
          navigator pdf nevada.md
          navigator edit nevada.md
          navigator save nevada.md
          navigator format nevada.md
          navigator glossary
          navigator glossary Notation
          navigator ddl
          navigator list questions
          navigator list jurisdictions
          navigator list templates
          navigator show template nevada_trust
          navigator notation trusts__nevada
          navigator notation Sources/NavigatorDAL/Examples/Trusts/nevada.md
          navigator notation trusts__nevada --person 1
          navigator agent setup
        """
    )
}

Task {
    do {
        guard arguments.count > 1 else {
            printUsage()
            exit(1)
        }

        let commandName = arguments[1]
        let command: Command

        switch commandName {
        case "lint":
            let path = arguments.count > 2 ? arguments[2] : "."
            command = LintCommand(path: path)

        case "import":
            let directoryPath = arguments.count > 2 ? arguments[2] : "."
            command = ImportCommand(directoryPath: directoryPath)

        case "pdf":
            guard arguments.count > 2 else {
                print("Error: Missing file argument for pdf command")
                print("Usage: navigator pdf <file>")
                exit(1)
            }
            let filePath = arguments[2]
            command = PDFCommand(inputPath: filePath)

        case "edit":
            guard arguments.count > 2 else {
                print("Error: Missing file argument for edit command")
                print("Usage: navigator edit <file>")
                exit(1)
            }
            let filePath = arguments[2]
            command = EditCommand(filePath: filePath)

        case "save":
            guard arguments.count > 2 else {
                print("Error: Missing file argument for save command")
                print("Usage: navigator save <file>")
                exit(1)
            }
            let filePath = arguments[2]
            command = SaveCommand(filePath: filePath)

        case "format":
            guard arguments.count > 2 else {
                print("Error: Missing file argument for format command")
                print("Usage: navigator format <file>")
                exit(1)
            }
            let filePath = arguments[2]
            command = FormatCommand(filePath: filePath)

        case "glossary":
            let term = arguments.count > 2 ? arguments[2] : nil
            command = GlossaryCommand(term: term)

        case "ddl":
            command = DDLCommand()

        case "list":
            let subCommand = arguments.count > 2 ? arguments[2] : ""
            switch subCommand {
            case "questions":
                command = QuestionsListCommand()
            case "jurisdictions":
                command = JurisdictionsListCommand()
            case "templates":
                command = TemplatesListCommand()
            default:
                print("Error: Unknown list subcommand: '\(subCommand)'")
                print("Usage: navigator list <questions|jurisdictions|templates>")
                exit(1)
            }

        case "show":
            let subCommand = arguments.count > 2 ? arguments[2] : ""
            switch subCommand {
            case "template":
                guard arguments.count > 3 else {
                    print("Error: Missing code argument for show template command")
                    print("Usage: navigator show template <code>")
                    exit(1)
                }
                command = ShowTemplateCommand(code: arguments[3])
            default:
                print("Error: Unknown show subcommand: '\(subCommand)'")
                print("Usage: navigator show template <code>")
                exit(1)
            }

        case "notation":
            guard arguments.count > 2 else {
                print("Error: Missing template path for notation command")
                print("Usage: navigator notation <template-path> [--person <id>] [--entity <id>]")
                exit(1)
            }
            let templatePath = arguments[2]
            // CLI defaults to a fresh UUID; callers can override with --person <uuid>.
            // The CLI is dev-only and doesn't yet resolve a "current local user".
            var personID: UUID = UUID()
            var entityID: UUID? = nil
            var i = 3
            while i < arguments.count {
                switch arguments[i] {
                case "--person":
                    guard i + 1 < arguments.count, let id = UUID(uuidString: arguments[i + 1]) else {
                        print("Error: --person requires a valid UUID")
                        exit(1)
                    }
                    personID = id
                    i += 2
                case "--entity":
                    guard i + 1 < arguments.count, let id = UUID(uuidString: arguments[i + 1]) else {
                        print("Error: --entity requires a valid UUID")
                        exit(1)
                    }
                    entityID = id
                    i += 2
                default:
                    i += 1
                }
            }
            command = NotationCommand(
                templatePath: templatePath,
                personID: personID,
                entityID: entityID
            )

        case "agent":
            let subCommand = arguments.count > 2 ? arguments[2] : ""
            switch subCommand {
            case "setup":
                command = AgentSetupCommand()
            default:
                print("Error: Unknown agent subcommand: '\(subCommand)'")
                print("Usage: navigator agent setup")
                exit(1)
            }

        case "--help", "-h":
            printUsage()
            exit(0)

        case "--version", "-v":
            print("navigator version dev (built from source)")
            print("https://github.com/neon-law-foundation/Navigator")
            exit(0)

        default:
            throw CommandError.unknownCommand(commandName)
        }

        try await command.run()
        exit(0)
    } catch let error as CommandError {
        switch error {
        case .lintFailed:
            exit(1)
        default:
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

dispatchMain()
