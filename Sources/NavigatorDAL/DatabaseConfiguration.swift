import FluentKit
import Foundation
import Logging
import Yams

/// Configuration utility for the Standards data access layer.
public struct NavigatorDALConfiguration {

    /// All migrations in order for the Standards database schema.
    ///
    /// Register these with your application's migration system to set up the Standards schema.
    /// The order matters — each migration depends on the tables created by earlier ones.
    public static var migrations: [any Migration] {
        [
            CreatePeople(),
            CreateUsers(),
            CreateJurisdictions(),
            CreateEntityTypes(),
            CreateEntities(),
            CreateShareClasses(),
            CreateBlobs(),
            CreateProjects(),
            CreateCredentials(),
            CreateRelationshipLogs(),
            CreateDisclosures(),
            CreateQuestions(),
            CreateMailrooms(),
            CreateAddresses(),
            CreatePersonEntityRoles(),
            CreateGitRepositories(),
            CreateTemplates(),
            CreateNotations(),
            CreateAnswers(),
            CreateLetters(),
            CreateShareIssuances(),
            CreateDocuments(),
            CreatePersonProjectRoles(),
            CreateRetainers(),
            CreateRetainerProjects(),
            CreateUserRoleAudit(),
            CreateEmailMessagesAndAttachments(),
            CreateEntityBillingProfiles(),
            CreateInvoices(),
            CreateInvoiceLineItems(),
        ]
    }

    /// Run seeds from YAML files and return the count of records seeded.
    public static func runSeeds(on database: Database, logger: Logger) async throws -> Int {
        var totalSeeds = 0
        let seedOrder: [String] = [
            "Project",
            "GitRepository",
            "Jurisdiction",
            "EntityType",
            "Question",
            "Person",
            "User",
            "Entity",
            "EntityBillingProfile",
            "Invoice",
            "InvoiceLineItem",
            "Credential",
            "Mailroom",
            "Address",
            "PersonEntityRole",
            "PersonProjectRole",
            "Answer",
        ]

        logger.info("Starting seed process")

        for modelName in seedOrder {
            logger.info("Processing seeds for model: \(modelName)")

            if let seedFile = findSeedFile(for: modelName, logger: logger) {
                logger.info("Loading seed file: \(seedFile)")
                let count = try await processSeedFile(
                    seedFile,
                    modelName: modelName,
                    database: database,
                    logger: logger
                )
                totalSeeds += count
            }
        }

        try await seedNotationsFromExamples(on: database, logger: logger)
        try await seedSampleNotations(on: database, logger: logger)

        logger.info("Seed process completed: \(totalSeeds) total records")
        return totalSeeds
    }

    /// Find seed file for a model
    private static func findSeedFile(for modelName: String, logger: Logger) -> String? {
        // Try Bundle.module first
        if let seedURL = Bundle.module.url(forResource: "Seeds/\(modelName)", withExtension: "yaml") {
            if FileManager.default.fileExists(atPath: seedURL.path) {
                logger.info("Found seed file via Bundle.module: \(seedURL.path)")
                return modelName
            }
        }

        // Fallback: try relative path
        let fallbackPath = "Sources/NavigatorDAL/Seeds/\(modelName).yaml"
        if FileManager.default.fileExists(atPath: fallbackPath) {
            logger.info("Found seed file via fallback path: \(fallbackPath)")
            return modelName
        }

        logger.warning("No seed file found for model: \(modelName)")
        return nil
    }

    /// Process a seed file and return count of records seeded
    private static func processSeedFile(
        _ seedFile: String,
        modelName: String,
        database: Database,
        logger: Logger
    ) async throws -> Int {
        var seedURL: URL?

        // Try Bundle.module first
        if let bundleURL = Bundle.module.url(forResource: "Seeds/\(seedFile)", withExtension: "yaml") {
            if FileManager.default.fileExists(atPath: bundleURL.path) {
                seedURL = bundleURL
            }
        }

        // Fallback: try relative path
        if seedURL == nil {
            let fallbackPath = "Sources/NavigatorDAL/Seeds/\(seedFile).yaml"
            if FileManager.default.fileExists(atPath: fallbackPath) {
                seedURL = URL(fileURLWithPath: fallbackPath)
            }
        }

        guard let finalURL = seedURL else {
            logger.warning("Seed file not found: Seeds/\(seedFile).yaml")
            return 0
        }

        logger.info("Processing seed file: \(finalURL.path)")

        // Read and parse YAML file
        let yamlData = try Data(contentsOf: finalURL)
        let seedData = try parseYAML(from: yamlData)

        logger.info("Found \(seedData.records.count) \(modelName) records with lookup fields: \(seedData.lookupFields)")

        // Process each record
        for (index, record) in seedData.records.enumerated() {
            do {
                try await insertRecord(
                    record: record,
                    modelName: modelName,
                    lookupFields: seedData.lookupFields,
                    database: database,
                    logger: logger
                )
                logger.debug("✓ Inserted \(modelName) record \(index + 1)/\(seedData.records.count)")
            } catch {
                // PSQLError's `description` is redacted ("Generic description to prevent
                // accidental leakage of sensitive data"); `String(reflecting:)` reaches the
                // unredacted `debugDescription` (SQLSTATE, message, bound metadata). Safe
                // here because seed inputs are repo-committed YAML, not user secrets.
                logger.error(
                    "✗ Failed to insert \(modelName) record \(index + 1): \(String(reflecting: error))"
                )
            }
        }

        logger.info("Completed processing \(seedData.records.count) \(modelName) records")
        return seedData.records.count
    }

    /// Parse YAML data into seed structure
    private static func parseYAML(from data: Data) throws -> SeedData {
        let yaml = try Yams.load(yaml: String(data: data, encoding: .utf8)!)

        guard let yamlDict = yaml as? [String: Any] else {
            throw SeedError.invalidYAMLStructure
        }

        let lookupFields = yamlDict["lookup_fields"] as? [String] ?? []
        let records = yamlDict["records"] as? [[String: Any]] ?? []

        return SeedData(lookupFields: lookupFields, records: records)
    }

    /// Insert or update a record using native Fluent
    private static func insertRecord(
        record: [String: Any],
        modelName: String,
        lookupFields: [String],
        database: Database,
        logger: Logger
    ) async throws {
        switch modelName {
        case "Project":
            try await insertProject(record: record, lookupFields: lookupFields, database: database)
        case "GitRepository":
            try await insertGitRepository(record: record, lookupFields: lookupFields, database: database)
        case "Jurisdiction":
            try await insertJurisdiction(record: record, lookupFields: lookupFields, database: database)
        case "EntityType":
            try await insertEntityType(record: record, lookupFields: lookupFields, database: database)
        case "Question":
            try await insertQuestion(record: record, lookupFields: lookupFields, database: database)
        case "Person":
            try await insertPerson(record: record, lookupFields: lookupFields, database: database)
        case "User":
            try await insertUser(record: record, lookupFields: lookupFields, database: database)
        case "Entity":
            try await insertEntity(record: record, lookupFields: lookupFields, database: database)
        case "EntityBillingProfile":
            try await insertEntityBillingProfile(record: record, lookupFields: lookupFields, database: database)
        case "Invoice":
            try await insertInvoice(record: record, lookupFields: lookupFields, database: database)
        case "InvoiceLineItem":
            try await insertInvoiceLineItem(record: record, lookupFields: lookupFields, database: database)
        case "Credential":
            try await insertCredential(record: record, lookupFields: lookupFields, database: database)
        case "Address":
            try await insertAddress(record: record, lookupFields: lookupFields, database: database)
        case "Mailroom":
            try await insertMailroom(record: record, lookupFields: lookupFields, database: database)
        case "PersonEntityRole":
            try await insertPersonEntityRole(record: record, lookupFields: lookupFields, database: database)
        case "PersonProjectRole":
            try await insertPersonProjectRole(record: record, lookupFields: lookupFields, database: database)
        case "Answer":
            try await insertAnswer(record: record, lookupFields: lookupFields, database: database)
        default:
            logger.warning("Unknown model type: \(modelName)")
        }
    }

}

// MARK: - Supporting Types

private struct SeedData {
    let lookupFields: [String]
    let records: [[String: Any]]
}

private enum SeedError: Error {
    case invalidYAMLStructure
    case missingRequiredField(String)
    case unsupportedModel(String)
}
