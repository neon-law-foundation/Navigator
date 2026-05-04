import Foundation

/// Identifies who triggered a notation workflow transition.
///
/// Actor must reference a real database row — no freeform strings.
/// Staff are `person` actors; the service layer checks their role.
///
/// ## Topics
///
/// ### Cases
///
/// - ``person(id:)``
/// - ``entity(id:)``
/// - ``system``
public enum NotationActor: Codable, Sendable, Equatable {

    /// A person from the people table (respondent or staff).
    case person(id: UUID)

    /// An entity from the entities table (respondent).
    case entity(id: UUID)

    /// An automated transition with no human actor.
    case system

    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "person":
            let id = try container.decode(UUID.self, forKey: .id)
            self = .person(id: id)
        case "entity":
            let id = try container.decode(UUID.self, forKey: .id)
            self = .entity(id: id)
        case "system":
            self = .system
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown actor type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .person(let id):
            try container.encode("person", forKey: .type)
            try container.encode(id, forKey: .id)
        case .entity(let id):
            try container.encode("entity", forKey: .type)
            try container.encode(id, forKey: .id)
        case .system:
            try container.encode("system", forKey: .type)
        }
    }
}

/// Records one workflow transition on a notation.
///
/// The full audit trail of a notation's lifecycle is its `stateHistory` array of `NotationEvent`s.
/// Current state is always `stateHistory.last?.toState`. A notation is closed when `toState == "END"`.
///
/// ## Topics
///
/// ### Properties
///
/// - ``fromState``
/// - ``condition``
/// - ``toState``
/// - ``actor``
/// - ``at``
/// - ``note``
/// - ``addressID``
/// - ``documentURL``
public struct NotationEvent: Codable, Sendable, Equatable {

    /// State we were in when this event was recorded.
    ///
    /// Must be a key in `template.workflow`.
    public let fromState: String

    /// Condition that triggered the transition.
    ///
    /// Must be a key in `template.workflow[fromState].transitions`.
    public let condition: String

    /// Resulting state after the transition.
    ///
    /// Derived from the workflow and stored for readability.
    /// Validated against `template.workflow[fromState].transitions[condition]` on write.
    public let toState: String

    /// Who triggered this transition. References a real database ID.
    public let actor: NotationActor

    /// When this event occurred.
    public let at: Date

    /// Optional human-readable note.
    public let note: String?

    /// The address involved in this event, if applicable.
    ///
    /// Set on mailroom send/receive events. References `addresses.id`.
    public let addressID: UUID?

    /// The URL of the rendered document, if applicable.
    ///
    /// Set on document generation events.
    public let documentURL: String?

    /// Creates a new notation event.
    public init(
        fromState: String,
        condition: String,
        toState: String,
        actor: NotationActor,
        at: Date,
        note: String? = nil,
        addressID: UUID? = nil,
        documentURL: String? = nil
    ) {
        self.fromState = fromState
        self.condition = condition
        self.toState = toState
        self.actor = actor
        self.at = at
        self.note = note
        self.addressID = addressID
        self.documentURL = documentURL
    }
}
