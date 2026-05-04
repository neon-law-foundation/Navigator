import Fluent
import FluentSQLiteDriver
import Foundation
import NavigatorDAL
import Testing
import Vapor

@Suite("NotationService")
struct NotationServiceTests {

    // MARK: - Helpers

    private func makeTemplate(
        workflow: [String: [String: String]],
        respondentType: RespondentType = .entity,
        on db: Database
    ) async throws -> (Template, Entity) {
        let jurisdiction = Jurisdiction()
        jurisdiction.name = "Test Jurisdiction \(UUID())"
        jurisdiction.code = String(UUID().uuidString.prefix(5))
        jurisdiction.jurisdictionType = .state
        try await jurisdiction.save(on: db)

        let entityType = EntityType()
        entityType.$jurisdiction.id = jurisdiction.id!
        entityType.name = "LLC \(UUID())"
        try await entityType.save(on: db)

        let entity = Entity()
        entity.name = "Test Entity \(UUID())"
        entity.$legalEntityType.id = entityType.id!
        try await entity.save(on: db)

        let project = Project()
        project.codename = "test-project-\(UUID().uuidString.prefix(8))"
        try await project.save(on: db)

        let uid = UUID().uuidString
        let gitRepo = GitRepository(
            awsAccountID: "123456789012",
            awsRegion: "us-east-1",
            codecommitRepositoryID: uid,
            repositoryName: "test-repo-\(uid.prefix(8))",
            repositoryARN: "arn:aws:codecommit:us-east-1:123456789012:\(uid.prefix(8))"
        )
        gitRepo.$project.id = project.id!
        try await gitRepo.save(on: db)

        let template = Template()
        template.$gitRepository.id = gitRepo.id!
        template.code = "test__template__\(UUID())"
        template.version = "abc123"
        template.title = "Test Template \(UUID())"
        template.description = "A test template"
        template.respondentType = respondentType
        template.markdownContent = "# Test"
        template.frontmatter = [:]
        template.questionnaire = [:]
        template.workflow = workflow
        try await template.save(on: db)

        return (template, entity)
    }

    // MARK: - createNotation

    @Test("createNotation creates initial system event from BEGIN")
    func testCreateNotationCreatesInitialEvent() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "staff_review"],
                "staff_review": ["_": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            #expect(notation.stateHistory.count == 1)
            let event = notation.stateHistory[0]
            #expect(event.fromState == "BEGIN")
            #expect(event.condition == "_")
            #expect(event.toState == "staff_review")
            #expect(event.actor == .system)
        }
    }

    // MARK: - appendEvent

    @Test("appendEvent appends a valid transition")
    func testAppendEventAppends() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "staff_review"],
                "staff_review": ["approved": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            let person = Person()
            person.email = "staff@example.com"
            person.name = "Staff Member"
            try await person.save(on: db)

            let updated = try await service.appendEvent(
                to: notation.id!,
                fromState: "staff_review",
                condition: "approved",
                actor: .person(id: person.id!)
            )

            #expect(updated.stateHistory.count == 2)
            #expect(updated.stateHistory[1].toState == "END")
            #expect(updated.stateHistory[1].actor == .person(id: person.id!))
        }
    }

    @Test("appendEvent rejects append to closed notation")
    func testAppendEventRejectsClosed() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "END"]
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            #expect(notation.stateHistory.last?.toState == "END")

            await #expect(throws: Error.self) {
                _ = try await service.appendEvent(
                    to: notation.id!,
                    fromState: "END",
                    condition: "_",
                    actor: .system
                )
            }
        }
    }

    @Test("appendEvent rejects wrong fromState")
    func testAppendEventRejectsWrongFromState() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "staff_review"],
                "staff_review": ["_": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            await #expect(throws: Error.self) {
                _ = try await service.appendEvent(
                    to: notation.id!,
                    fromState: "wrong_state",
                    condition: "_",
                    actor: .system
                )
            }
        }
    }

    @Test("appendEvent rejects invalid condition")
    func testAppendEventRejectsInvalidCondition() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "staff_review"],
                "staff_review": ["approved": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            let person = Person()
            person.email = "s@e.com"
            person.name = "Staff"
            try await person.save(on: db)

            await #expect(throws: Error.self) {
                _ = try await service.appendEvent(
                    to: notation.id!,
                    fromState: "staff_review",
                    condition: "no_such_condition",
                    actor: .person(id: person.id!)
                )
            }
        }
    }

    @Test("appendEvent rejects entity actor for staff_review state")
    func testAppendEventRejectsEntityActorForStaffReviewState() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "staff_review"],
                "staff_review": ["_": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            // staff_review resolves to StaffReviewStep which requires a person actor
            await #expect(throws: Error.self) {
                _ = try await service.appendEvent(
                    to: notation.id!,
                    fromState: "staff_review",
                    condition: "_",
                    actor: .entity(id: entity.id!)
                )
            }
        }
    }

    @Test("appendEvent rejects system actor for staff_review state")
    func testAppendEventRejectsSystemActorForStaffReviewState() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "staff_review"],
                "staff_review": ["_": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            await #expect(throws: Error.self) {
                _ = try await service.appendEvent(
                    to: notation.id!,
                    fromState: "staff_review",
                    condition: "_",
                    actor: .system
                )
            }
        }
    }

    @Test("appendEvent allows respondent entity actor for notarization state")
    func testAppendEventAllowsRespondentEntityActorForNotarizationState() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "notarization__for_trustee"],
                "notarization__for_trustee": ["yes": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            // notarization resolves to NotarizationStep with actor .respondent
            // entity actor matches notation.entity_id — allowed
            let updated = try await service.appendEvent(
                to: notation.id!,
                fromState: "notarization__for_trustee",
                condition: "yes",
                actor: .entity(id: entity.id!)
            )

            #expect(updated.stateHistory.last?.toState == "END")
        }
    }

    @Test("appendEvent throws for unregistered step prefix")
    func testAppendEventThrowsForUnregisteredPrefix() async throws {
        try await withDatabase { db in
            let workflow: [String: [String: String]] = [
                "BEGIN": ["_": "payment__for_filing"],
                "payment__for_filing": ["yes": "END"],
            ]
            let (template, entity) = try await makeTemplate(workflow: workflow, on: db)
            let service = NotationService(database: db)

            let notation = try await service.createNotation(
                templateID: template.id!,
                personID: nil,
                entityID: entity.id!
            )

            await #expect(throws: Error.self) {
                _ = try await service.appendEvent(
                    to: notation.id!,
                    fromState: "payment__for_filing",
                    condition: "yes",
                    actor: .entity(id: entity.id!)
                )
            }
        }
    }
}
