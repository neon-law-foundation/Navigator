import Foundation
import Logging
import NavigatorDAL
import NavigatorRules

struct ImportCommand: Command {
    let directoryPath: String

    func run() async throws {
        let logger = Logger(label: "navigator-cli")
        let url: URL

        if directoryPath == "." {
            url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        } else {
            url = URL(fileURLWithPath: directoryPath)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            print("Error: '\(directoryPath)' is not a valid directory")
            throw CommandError.invalidPath(directoryPath)
        }

        print("📋 Checking git repository status...")

        guard try isGitRepository(at: url) else {
            print("❌ Error: \(url.path) is not a git repository")
            print("   Run 'git init' to initialize a repository first")
            throw CommandError.setupFailed("Not a git repository")
        }

        guard try !hasUncommittedChanges(at: url) else {
            print("❌ Error: Repository has uncommitted changes")
            print("   Commit or stash your changes before importing")
            throw CommandError.setupFailed("Uncommitted changes detected")
        }

        let gitRepositoryID = try getGitRepositoryID(at: url)
        let version = try getCurrentCommitSHA(at: url)

        print("📦 Git Repository ID: \(gitRepositoryID)")
        print("📝 Git Commit SHA: \(version)")
        print("")
        print("📋 Validating markdown files in: \(url.path)")

        let dbManager = try await DatabaseManager()
        let database = dbManager.getDatabase()

        let questionRepository = QuestionRepository(database: database)
        let allQuestions = try await questionRepository.findAll()
        let validCodes = Set(allQuestions.map(\.code))

        let importRules: [Rule] = [
            F101_TitleRequired(),
            F102_RespondentTypeRequired(),
            F104_FlowQuestionCodes(validCodes: validCodes),
        ]
        let importEngine = RuleEngine(rules: importRules)
        let importLintResult = try importEngine.lint(directory: url)

        if !importLintResult.isValid {
            print(
                "❌ Found \(importLintResult.totalViolationCount) violation(s) in \(importLintResult.fileViolations.count) file(s):\n"
            )
            for fileViolation in importLintResult.fileViolations {
                let relativePath = makeRelativePath(fileViolation.file, from: url)
                print("\(relativePath):")
                for violation in fileViolation.violations {
                    var parts = ["[\(violation.ruleCode)]"]
                    if let line = violation.line { parts.append("Line \(line):") }
                    parts.append(violation.message)
                    if let context = violation.context, !context.isEmpty {
                        parts.append(
                            "(" + context.map { "\($0.key): \($0.value)" }.joined(separator: ", ") + ")"
                        )
                    }
                    print("  " + parts.joined(separator: " "))
                }
                print("")
            }
            try await dbManager.shutdown()
            throw CommandError.lintFailed
        }

        let templateService = TemplateService(database: database)
        let importer = TemplateImporter(templateService: templateService, logger: logger)

        let filesToImport = try collectMarkdownFiles(in: url)

        var importCount = 0
        var failCount = 0

        for fileURL in filesToImport {
            do {
                let template = try await importer.importMarkdownFile(
                    fileURL,
                    gitRepositoryID: gitRepositoryID,
                    version: version
                )
                let relativePath = makeRelativePath(fileURL, from: url)
                print("✅ Imported: \(relativePath) -> \(template.code ?? "unknown") - \(template.title)")
                importCount += 1
            } catch let error as TemplateError {
                let relativePath = makeRelativePath(fileURL, from: url)
                print("❌ Failed to import \(relativePath): \(error.errorDescription ?? error.localizedDescription)")
                failCount += 1
            } catch {
                let relativePath = makeRelativePath(fileURL, from: url)
                print("❌ Failed to import \(relativePath): \(error)")
                failCount += 1
            }
        }

        try await dbManager.shutdown()

        print("\n" + String(repeating: "=", count: 50))
        print("📊 Import Summary:")
        print("   ✅ Successfully imported: \(importCount) template(s)")
        if failCount > 0 {
            print("   ❌ Failed: \(failCount) template(s)")
        }
        print(String(repeating: "=", count: 50))

        if failCount > 0 {
            throw CommandError.setupFailed("Some imports failed")
        }
    }

    private func collectMarkdownFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            throw CommandError.setupFailed("Cannot enumerate directory: \(directory.path)")
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard FileFilters.shouldValidate(fileURL) else { continue }
            files.append(fileURL)
        }
        return files
    }

    private func isGitRepository(at directory: URL) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "rev-parse", "--git-dir"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    private func hasUncommittedChanges(at directory: URL) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "status", "--porcelain"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func getCurrentCommitSHA(at directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "rev-parse", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CommandError.setupFailed("Failed to get current commit SHA")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let sha =
            String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !sha.isEmpty else {
            throw CommandError.setupFailed("No commits found in repository")
        }

        return sha
    }

    private func getGitRepositoryID(at directory: URL) throws -> UUID {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "remote", "get-url", "origin"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CommandError.setupFailed("Failed to get git remote origin URL")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let remoteURL =
            String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !remoteURL.isEmpty else {
            throw CommandError.setupFailed("No remote origin configured")
        }

        let repoID = hashRepositoryURL(remoteURL)
        return repoID
    }

    /// Derives a stable UUID from a git remote URL using a deterministic hash.
    ///
    /// The CLI does not look up real git_repositories.id values — it synthesises one
    /// per remote URL so repeated imports of the same repo collapse onto the same row.
    /// The result is not RFC 4122 v5 (no namespace ceremony), but it is deterministic
    /// for the same input and unlikely to collide in dev workflows.
    private func hashRepositoryURL(_ url: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        var i = 0
        for byte in url.utf8 {
            bytes[i % 16] = bytes[i % 16] &+ byte
            i &+= 1
        }
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }

    private func makeRelativePath(_ file: URL, from base: URL) -> String {
        base.path.isEmpty
            ? file.path : file.path.replacingOccurrences(of: base.path + "/", with: "")
    }
}
