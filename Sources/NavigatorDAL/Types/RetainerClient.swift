import Foundation

/// Identifies a client on a retainer — either a person or an entity.
///
/// Stored as a JSONB array on the ``Retainer`` model's `clients` column.
/// Mirrors the ``NotationActor`` polymorphic pattern but is always a concrete
/// database reference (no `system` case).
public struct RetainerClient: Codable, Sendable, Equatable {

    /// The kind of database record this client references.
    public enum ClientType: String, Codable, Sendable {
        case person
        case entity
    }

    /// Whether this client is a person or an entity.
    public let type: ClientType

    /// The primary key (UUID) of the referenced person or entity row.
    public let id: UUID

    /// Creates a new `RetainerClient`.
    public init(type: ClientType, id: UUID) {
        self.type = type
        self.id = id
    }
}
