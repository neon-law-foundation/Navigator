import Foundation

/// Errors related to notation operations and validation.
public enum NotationError: Error, LocalizedError {

    /// Template with specified ID not found.
    case templateNotFound(UUID)

    /// Notation with specified ID not found.
    case notationNotFound(UUID)

    /// No latest version found for the specified template.
    case noLatestVersionFound(repository: UUID, code: String)

    /// Attempted to create a notation from an outdated template version.
    case outdatedVersion(
        requestedTemplateID: UUID,
        requestedVersion: String,
        requestedInsertedAt: Date,
        latestTemplateID: UUID,
        latestVersion: String,
        latestInsertedAt: Date,
        code: String,
        repositoryID: UUID
    )

    /// An active notation already exists for this template and respondents.
    case activeAssignmentExists(templateID: UUID, personID: UUID?, entityID: UUID?)

    /// Notation is invalid for the template's respondent type.
    case invalidAssignment(String)

    /// Attempted to append an event to a closed notation (toState == "END").
    case closedNotation(UUID)

    /// The provided `fromState` does not match the notation's current state.
    case fromStateMismatch(expected: String, provided: String)

    /// No transition exists for the given state and condition in the template workflow.
    case invalidTransition(fromState: String, condition: String)

    /// The actor does not match the state's declared actor class.
    case actorMismatch(expected: String, provided: NotationActor)

    /// The template's BEGIN step has no `_` transition and multiple (or zero) transitions,
    /// so the initial state cannot be determined unambiguously.
    case noUniqueBeginTransition(String)

    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let id):
            return "Template with ID \(id) not found"
        case .notationNotFound(let id):
            return "Notation with ID \(id) not found"
        case .noLatestVersionFound(let repo, let code):
            return "No versions found for template '\(code)' in repository \(repo)"
        case .outdatedVersion(
            let reqID,
            let reqVer,
            let reqDate,
            let latestID,
            let latestVer,
            let latestDate,
            let code,
            let repoID
        ):
            return """
                Cannot create notation from outdated template version.

                Requested: Template ID \(reqID), version '\(reqVer)', created \(reqDate)
                Latest: Template ID \(latestID), version '\(latestVer)', created \(latestDate)

                Please use the latest version of '\(code)' from repository \(repoID).
                """
        case .activeAssignmentExists(let templateID, let personID, let entityID):
            let personDescription = personID.map { $0.uuidString } ?? "nil"
            let entityDescription = entityID.map { $0.uuidString } ?? "nil"
            return
                "Active notation already exists for template \(templateID), person \(personDescription), entity \(entityDescription)"
        case .invalidAssignment(let reason):
            return "Invalid notation: \(reason)"
        case .closedNotation(let id):
            return "Cannot append event to closed notation \(id) (toState == END)"
        case .fromStateMismatch(let expected, let provided):
            return
                "State mismatch: expected '\(expected)' but fromState '\(provided)' was provided"
        case .invalidTransition(let fromState, let condition):
            return
                "No transition for condition '\(condition)' from state '\(fromState)' in template workflow"
        case .actorMismatch(let expected, let provided):
            return "Actor mismatch: expected \(expected), got \(provided)"
        case .noUniqueBeginTransition(let code):
            return
                "Template '\(code)' BEGIN step has no '_' transition and multiple (or zero) transitions — cannot determine initial state"
        }
    }
}
