import FluentKit
import Foundation

/// Service responsible for creating and managing notations with version validation.
public actor NotationService {
    private let database: Database
    private let templateService: TemplateService

    public init(database: Database) {
        self.database = database
        self.templateService = TemplateService(database: database)
    }

    /// Creates a new notation with an initial system event at BEGIN.
    ///
    /// Enforces the business rule that notations can only be created from the latest version
    /// of a template. The initial workflow event transitions from `BEGIN` using the first
    /// transition defined in the template's workflow, with `actor: .system`.
    ///
    /// - Parameters:
    ///   - templateID: The template to assign.
    ///   - personID: The person to assign to (if applicable).
    ///   - entityID: The entity to assign to (if applicable).
    ///   - answers: Questionnaire answers collected at creation time, keyed by question code.
    ///   - renderedContent: The template markdown with questionnaire answers interpolated,
    ///     or `nil` when the template has no questionnaire.
    /// - Returns: The created notation.
    /// - Throws: ``NotationError`` if validation fails.
    public func createNotation(
        templateID: UUID,
        personID: UUID?,
        entityID: UUID?,
        answers: [String: UUID] = [:],
        renderedContent: String? = nil
    ) async throws -> Notation {

        guard let template = try await Template.find(templateID, on: database) else {
            throw NotationError.templateNotFound(templateID)
        }

        try await template.$gitRepository.load(on: database)

        guard let gitRepo = template.gitRepository else {
            throw NotationError.templateNotFound(templateID)
        }
        let gitRepoID = try gitRepo.requireID()

        guard let code = template.code else {
            throw NotationError.templateNotFound(templateID)
        }

        guard
            let latestVersion = try await templateService.findLatestVersion(
                gitRepositoryID: gitRepoID,
                code: code
            )
        else {
            throw NotationError.noLatestVersionFound(
                repository: gitRepoID,
                code: code
            )
        }

        let latestTemplateID = try latestVersion.requireID()
        if latestTemplateID != templateID {
            throw NotationError.outdatedVersion(
                requestedTemplateID: templateID,
                requestedVersion: template.version,
                requestedInsertedAt: template.insertedAt!,
                latestTemplateID: latestTemplateID,
                latestVersion: latestVersion.version,
                latestInsertedAt: latestVersion.insertedAt!,
                code: code,
                repositoryID: gitRepoID
            )
        }

        let hasActive = try await Notation.hasActiveAssignment(
            templateID: templateID,
            personID: personID,
            entityID: entityID,
            on: database
        )

        if hasActive {
            throw NotationError.activeAssignmentExists(
                templateID: templateID,
                personID: personID,
                entityID: entityID
            )
        }

        let notation = Notation()
        notation.$template.id = templateID
        notation.$person.id = personID
        notation.$entity.id = entityID

        let initialEvent = try makeInitialEvent(from: template)
        notation.stateHistory = [initialEvent]
        notation.answers = answers
        notation.renderedContent = renderedContent

        try await notation.validate(on: database)
        try await notation.save(on: database)

        return notation
    }

    /// Creates a notation using repository and code, automatically using the latest template version.
    ///
    /// This convenience method finds the latest version of a template by its repository and code,
    /// then creates a notation against it.
    ///
    /// - Parameters:
    ///   - gitRepositoryID: The ID of the git repository.
    ///   - code: The template code.
    ///   - personID: The person to assign to (if applicable).
    ///   - entityID: The entity to assign to (if applicable).
    /// - Returns: The created notation.
    /// - Throws: ``NotationError`` if no latest version is found or validation fails.
    public func createNotationByCode(
        gitRepositoryID: UUID,
        code: String,
        personID: UUID?,
        entityID: UUID?
    ) async throws -> Notation {
        guard
            let latestTemplate = try await templateService.findLatestVersion(
                gitRepositoryID: gitRepositoryID,
                code: code
            )
        else {
            throw NotationError.noLatestVersionFound(
                repository: gitRepositoryID,
                code: code
            )
        }

        return try await createNotation(
            templateID: try latestTemplate.requireID(),
            personID: personID,
            entityID: entityID
        )
    }

    /// Appends a workflow event to a notation's state history.
    ///
    /// Validates the transition against the template's workflow, confirms the current
    /// state matches `fromState`, and derives `toState` from the workflow — never trusting
    /// the caller's `toState`.
    ///
    /// - Parameters:
    ///   - notationID: The notation to update.
    ///   - fromState: The expected current state (must match `stateHistory.last?.toState`).
    ///   - condition: The transition condition (must be a key in `workflow[fromState].transitions`).
    ///   - actor: Who is triggering this transition.
    ///   - note: Optional human-readable note.
    /// - Returns: The updated notation.
    /// - Throws: ``NotationError`` if the transition is invalid or the actor doesn't match.
    public func appendEvent(
        to notationID: UUID,
        fromState: String,
        condition: String,
        actor: NotationActor,
        note: String? = nil
    ) async throws -> Notation {
        guard let notation = try await Notation.find(notationID, on: database) else {
            throw NotationError.notationNotFound(notationID)
        }

        if notation.stateHistory.last?.toState == "END" {
            throw NotationError.closedNotation(notationID)
        }

        let currentState = notation.stateHistory.last?.toState ?? "BEGIN"
        guard currentState == fromState else {
            throw NotationError.fromStateMismatch(expected: currentState, provided: fromState)
        }

        try await notation.$template.load(on: database)
        let workflow = notation.template.workflow

        guard let transitions = workflow[fromState] else {
            throw NotationError.invalidTransition(fromState: fromState, condition: condition)
        }

        guard let toState = transitions[condition] else {
            throw NotationError.invalidTransition(fromState: fromState, condition: condition)
        }

        let step = try resolveWorkflowStep(stateName: fromState, transitions: transitions)
        try validateActor(actor, class: step.actor, notation: notation)

        let event = NotationEvent(
            fromState: fromState,
            condition: condition,
            toState: toState,
            actor: actor,
            at: Date(),
            note: note
        )

        notation.stateHistory = notation.stateHistory + [event]
        try await notation.save(on: database)

        return notation
    }

    // MARK: - Private helpers

    private func makeInitialEvent(from template: Template) throws -> NotationEvent {
        let beginTransitions = template.workflow["BEGIN"] ?? [:]
        let toState: String
        if let explicit = beginTransitions["_"] {
            toState = explicit
        } else if beginTransitions.count == 1, let only = beginTransitions.values.first {
            toState = only
        } else {
            throw NotationError.noUniqueBeginTransition(template.code ?? "<unknown>")
        }
        return NotationEvent(
            fromState: "BEGIN",
            condition: "_",
            toState: toState,
            actor: .system,
            at: Date()
        )
    }

    private func validateActor(
        _ actor: NotationActor,
        class actorClass: ActorClass,
        notation: Notation
    ) throws {
        switch actorClass {
        case .system:
            guard actor == .system else {
                throw NotationError.actorMismatch(
                    expected: "system actor",
                    provided: actor
                )
            }
        case .staff:
            guard case .person = actor else {
                throw NotationError.actorMismatch(
                    expected: "person actor (staff)",
                    provided: actor
                )
            }
        case .respondent:
            let personID = notation.$person.id
            let entityID = notation.$entity.id
            let isPersonMatch: Bool
            if case .person(let id) = actor, id == personID {
                isPersonMatch = true
            } else {
                isPersonMatch = false
            }
            let isEntityMatch: Bool
            if case .entity(let id) = actor, id == entityID {
                isEntityMatch = true
            } else {
                isEntityMatch = false
            }
            guard isPersonMatch || isEntityMatch else {
                throw NotationError.actorMismatch(
                    expected: "respondent actor matching person_id or entity_id",
                    provided: actor
                )
            }
        }
    }
}
