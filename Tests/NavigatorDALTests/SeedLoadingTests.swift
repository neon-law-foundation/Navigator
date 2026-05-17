import Fluent
import FluentSQLiteDriver
import NavigatorDAL
import Testing
import Vapor

@Suite("Seed Loading Tests")
struct SeedLoadingTests {

    @Test("Seeds load without errors")
    func testSeedsLoadSuccessfully() async throws {
        try await withApplication { app in
            // Load all seed files
            let count = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Verify seeds were loaded
            #expect(count > 0, "No seeds were loaded")

            // Verify key tables have data
            let personCount = try await Person.query(on: app.db).count()
            #expect(personCount > 0, "No people were seeded")

            let jurisdictionCount = try await Jurisdiction.query(on: app.db).count()
            #expect(jurisdictionCount > 0, "No jurisdictions were seeded")
        }
    }

    @Test("Nick's person record loads correctly")
    func testNickPersonRecord() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Find Nick's person record
            let nick = try await Person.query(on: app.db)
                .filter(\.$email == "nick@neonlaw.com")
                .first()

            #expect(nick != nil, "Nick's person record not found")
            #expect(nick?.name == "Nick Shook")
            #expect(nick?.email == "nick@neonlaw.com")
        }
    }

    @Test("Nick's user account loads correctly")
    func testNickUserAccount() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Find Nick's person
            let nick = try await Person.query(on: app.db)
                .filter(\.$email == "nick@neonlaw.com")
                .first()

            #expect(nick != nil, "Nick's person record not found")

            // Find Nick's user account
            let user = try await User.query(on: app.db)
                .filter(\.$person.$id == nick!.id!)
                .first()

            #expect(user != nil, "Nick's user account not found")
            #expect(user?.role == .client, "User role should be client")
        }
    }

    @Test("Nick's bar credentials load correctly")
    func testNickCredentials() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Find Nick's person
            let nick = try await Person.query(on: app.db)
                .filter(\.$email == "nick@neonlaw.com")
                .first()

            #expect(nick != nil, "Nick's person record not found")

            // Find all credentials
            let credentials = try await Credential.query(on: app.db)
                .filter(\.$person.$id == nick!.id!)
                .with(\.$jurisdiction)
                .all()

            #expect(credentials.count == 3, "Expected 3 bar licenses (NV, CA, WA)")

            // Find specific credentials
            let nvLicense = credentials.first { $0.jurisdiction.code == "NV" }
            #expect(nvLicense != nil, "Nevada license not found")
            #expect(nvLicense?.licenseNumber == "13400")

            let caLicense = credentials.first { $0.jurisdiction.code == "CA" }
            #expect(caLicense != nil, "California license not found")
            #expect(caLicense?.licenseNumber == "337252")

            let waLicense = credentials.first { $0.jurisdiction.code == "WA" }
            #expect(waLicense != nil, "Washington license not found")
            #expect(waLicense?.licenseNumber == "63446")
        }
    }

    @Test("Nick's entities load correctly")
    func testNickEntities() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Verify Shook Law LLC
            let shookLaw = try await Entity.query(on: app.db)
                .filter(\.$name == "Shook Law LLC")
                .first()
            #expect(shookLaw != nil, "Shook Law LLC not found")

            // Verify Neon Law Foundation
            let neonLawFoundation = try await Entity.query(on: app.db)
                .filter(\.$name == "Neon Law Foundation")
                .first()
            #expect(neonLawFoundation != nil, "Neon Law Foundation not found")

            // Verify shook.family trust
            let shookFamily = try await Entity.query(on: app.db)
                .filter(\.$name == "shook.family")
                .first()
            #expect(shookFamily != nil, "shook.family trust not found")

            // Verify Nicholas Shook (Human entity)
            let nicholasShook = try await Entity.query(on: app.db)
                .filter(\.$name == "Nicholas Shook")
                .first()
            #expect(nicholasShook != nil, "Nicholas Shook entity not found")
        }
    }

    @Test("All US jurisdictions load")
    func testAllJurisdictionsLoad() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            let jurisdictions = try await Jurisdiction.query(on: app.db).all()

            // Should have all 50 states + DC + other jurisdictions
            #expect(jurisdictions.count >= 51, "Missing US jurisdictions")

            // Verify key states exist
            let nevada = jurisdictions.first { $0.code == "NV" }
            #expect(nevada != nil, "Nevada not found")
            #expect(nevada?.name == "Nevada")

            let california = jurisdictions.first { $0.code == "CA" }
            #expect(california != nil, "California not found")

            let washington = jurisdictions.first { $0.code == "WA" }
            #expect(washington != nil, "Washington not found")
        }
    }

    @Test("Entity types load correctly")
    func testEntityTypesLoad() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Find Nevada jurisdiction
            let nevada = try await Jurisdiction.query(on: app.db)
                .filter(\.$code == "NV")
                .first()

            #expect(nevada != nil, "Nevada jurisdiction not found")

            // Verify entity types for Nevada
            let entityTypes = try await EntityType.query(on: app.db)
                .filter(\.$jurisdiction.$id == nevada!.id!)
                .all()

            #expect(entityTypes.count > 0, "No entity types found for Nevada")

            // Verify specific types exist
            let llcType = entityTypes.first { $0.name == "Multi Member LLC" }
            #expect(llcType != nil, "Multi Member LLC type not found")

            let nonprofitType = entityTypes.first { $0.name == "501(c)(3) Non-Profit" }
            #expect(nonprofitType != nil, "Non-profit type not found")

            let trustType = entityTypes.first { $0.name == "Family Trust" }
            #expect(trustType != nil, "Family Trust type not found")
        }
    }

    @Test("Seed idempotency - running seeds twice does not create duplicates")
    func testSeedIdempotency() async throws {
        try await withApplication { app in
            // Load seeds first time
            let count1 = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            #expect(count1 > 0, "No seeds loaded on first run")

            // Count records after first load
            let personCount1 = try await Person.query(on: app.db).count()
            let entityCount1 = try await Entity.query(on: app.db).count()
            let credentialCount1 = try await Credential.query(on: app.db).count()

            // Load seeds second time
            let count2 = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            #expect(count2 == count1, "Seed count changed on second run")

            // Count records after second load
            let personCount2 = try await Person.query(on: app.db).count()
            let entityCount2 = try await Entity.query(on: app.db).count()
            let credentialCount2 = try await Credential.query(on: app.db).count()

            // Verify no duplicates were created
            #expect(personCount1 == personCount2, "Person records duplicated")
            #expect(entityCount1 == entityCount2, "Entity records duplicated")
            #expect(credentialCount1 == credentialCount2, "Credential records duplicated")

            // Verify Nick's person record still exists and is unique
            let nicks = try await Person.query(on: app.db)
                .filter(\.$email == "nick@neonlaw.com")
                .all()

            #expect(nicks.count == 1, "Nick's person record was duplicated")
        }
    }

    @Test("Seed data integrity - credentials link to correct person")
    func testCredentialPersonRelationship() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Find Nick's credentials
            let credentials = try await Credential.query(on: app.db)
                .with(\.$person)
                .with(\.$jurisdiction)
                .all()

            for credential in credentials {
                // Verify person relationship is loaded
                #expect(credential.person.email == "nick@neonlaw.com", "Credential not linked to Nick")

                // Verify jurisdiction relationship is loaded
                #expect(credential.jurisdiction.code != "", "Jurisdiction not loaded")

                // Verify license number is not empty
                #expect(!credential.licenseNumber.isEmpty, "License number is empty")
            }
        }
    }

    @Test("Seed data integrity - entities have valid entity types")
    func testEntityTypeRelationship() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            // Find all seeded entities
            let entities = try await Entity.query(on: app.db)
                .with(\.$legalEntityType)
                .all()

            #expect(entities.count > 0, "No entities were seeded")

            for entity in entities {
                // Verify entity type relationship is loaded
                #expect(!entity.legalEntityType.name.isEmpty, "Entity type name is empty")

                // Verify entity has a name
                #expect(!entity.name.isEmpty, "Entity name is empty")
            }
        }
    }

    @Test("Questions seed loads all prompts")
    func testQuestionsLoad() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            let questions = try await Question.query(on: app.db).all()
            #expect(questions.count > 0, "No questions were seeded")

            for question in questions {
                #expect(!question.code.isEmpty, "Question has empty code")
                #expect(!question.prompt.isEmpty, "Question has empty prompt")
            }

            let personalName = try await Question.query(on: app.db)
                .filter(\.$code == "personal_name")
                .first()
            #expect(personalName != nil, "personal_name question not found")
            #expect(personalName?.prompt == "What is your name?")
        }
    }

    @Test("Seed data integrity - addresses link to entities")
    func testAddressEntityRelationship() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(
                on: app.db,
                logger: app.logger
            )

            let shookLaw = try await Entity.query(on: app.db)
                .filter(\.$name == "Shook Law LLC")
                .first()

            #expect(shookLaw != nil, "Shook Law LLC not found")

            let address = try await Address.query(on: app.db)
                .filter(\.$entity.$id == shookLaw!.id!)
                .with(\.$entity)
                .first()

            #expect(address != nil, "Shook Law LLC address not found")
            #expect(address?.entity?.name == "Shook Law LLC", "Address not linked to correct entity")
        }
    }
}
