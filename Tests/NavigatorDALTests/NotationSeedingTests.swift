import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import Testing
import Vapor

@Suite("Template Seeding Tests")
struct TemplateSeedingTests {

    // MARK: - exampleCode unit tests

    @Test("Subdirectory and filename become double-underscore separated")
    func testExampleCodeSubdirectory() {
        let base = URL(fileURLWithPath: "/bundle/Examples")
        let file = URL(fileURLWithPath: "/bundle/Examples/Trusts/nevada.md")
        #expect(NavigatorDALConfiguration.exampleCode(for: file, relativeTo: base) == "trusts__nevada")
    }

    @Test("Code is lowercased")
    func testExampleCodeLowercased() {
        let base = URL(fileURLWithPath: "/bundle/Examples")
        let file = URL(fileURLWithPath: "/bundle/Examples/TrustAgreements/NevadaTrust.md")
        #expect(
            NavigatorDALConfiguration.exampleCode(for: file, relativeTo: base)
                == "trustagreements__nevadatrust"
        )
    }

    @Test("Flat file with no subdirectory uses filename only")
    func testExampleCodeFlatFile() {
        let base = URL(fileURLWithPath: "/bundle/Examples")
        let file = URL(fileURLWithPath: "/bundle/Examples/nevada.md")
        #expect(NavigatorDALConfiguration.exampleCode(for: file, relativeTo: base) == "nevada")
    }

    @Test("Deeply nested path produces triple-underscore-separated code")
    func testExampleCodeDeepNesting() {
        let base = URL(fileURLWithPath: "/bundle/Examples")
        let file = URL(fileURLWithPath: "/bundle/Examples/Business/LLC/Nevada/formation.md")
        #expect(
            NavigatorDALConfiguration.exampleCode(for: file, relativeTo: base)
                == "business__llc__nevada__formation"
        )
    }

    // MARK: - Integration tests

    @Test("Nevada trust is seeded as trusts__nevada")
    func testNevadaTrustCode() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(on: app.db, logger: app.logger)

            let service = TemplateService(database: app.db)
            let template = try await service.findLatestByCode("trusts__nevada")

            #expect(template != nil, "trusts__nevada not found after seeding")
            #expect(template?.title == "Nevada Trust")
            #expect(template?.respondentType == .entity)
        }
    }

    @Test("findAllLatest returns one entry per unique code")
    func testFindAllLatestDeduplicates() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(on: app.db, logger: app.logger)

            let service = TemplateService(database: app.db)
            let all = try await service.findAllLatest()
            let codes = all.compactMap(\.code)
            let uniqueCodes = Set(codes)

            #expect(codes.count == uniqueCodes.count, "findAllLatest returned duplicate codes")
        }
    }

    @Test("Seeding twice keeps trusts__nevada idempotent")
    func testTemplateSeedIdempotency() async throws {
        try await withApplication { app in
            _ = try await NavigatorDALConfiguration.runSeeds(on: app.db, logger: app.logger)
            _ = try await NavigatorDALConfiguration.runSeeds(on: app.db, logger: app.logger)

            let count = try await Template.query(on: app.db)
                .filter(\.$code == "trusts__nevada")
                .count()

            #expect(count == 1, "trusts__nevada was duplicated on second seed run")
        }
    }
}
