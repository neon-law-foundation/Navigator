import Foundation

/// The class of actor expected to trigger transitions out of a workflow step.
///
/// Encoded in the concrete ``WorkflowStep`` type — not stored in YAML or the database.
///
/// ## Topics
///
/// ### Cases
///
/// - ``respondent``
/// - ``staff``
/// - ``system``
public enum ActorClass: String, Codable, Sendable, CaseIterable {

    /// The person or entity the notation is assigned to.
    case respondent

    /// A person whose role includes staff privileges.
    case staff

    /// An automated transition with no human actor.
    case system
}
