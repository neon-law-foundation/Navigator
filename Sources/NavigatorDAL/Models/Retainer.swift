import FluentKit
import Foundation

/// Time-bound client access to one or more projects, gated on a signed retainer agreement.
///
/// A `Retainer` is the client-side counterpart to ``Disclosure``, which gates attorney access.
///
/// **Access model:**
/// - Attorney (staff): `Person → Credential → Disclosure → Project`
/// - Client: `Person|Entity → Retainer (clients JSON) → RetainerProject → Project`
/// - Admin: all projects regardless of disclosures or retainers
///
/// The retainer becomes active when the linked ``Notation`` reaches terminal state `"END"`.
/// `ends_at` is nil for ongoing matters and set explicitly when the matter closes.
///
/// ## Validity
///
/// A retainer grants project access only when all three conditions are met:
///
/// 1. `status == .active`
/// 2. `starts_at <= now`
/// 3. `ends_at == nil` OR `ends_at > now`
public final class Retainer: Model, @unchecked Sendable {
    public static let schema = "retainers"

    @ID(key: .id)
    public var id: UUID?

    /// Persons and/or entities covered by this retainer.
    ///
    /// Stored as a JSONB array. Each element is a ``RetainerClient`` identifying
    /// either a `people.id` or an `entities.id`.
    @Field(key: "clients")
    public var clients: [RetainerClient]

    /// The signed retainer agreement notation.
    @Parent(key: "notation_id")
    public var notation: Notation

    /// Current lifecycle state of this retainer.
    @Field(key: "status")
    public var status: RetainerStatus

    /// When client access began — set when the linked notation reaches terminal state.
    @OptionalField(key: "starts_at")
    public var startsAt: Date?

    /// When client access ends; nil for ongoing matters.
    @OptionalField(key: "ends_at")
    public var endsAt: Date?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    /// Projects accessible under this retainer.
    @Siblings(through: RetainerProject.self, from: \.$retainer, to: \.$project)
    public var projects: [Project]

    public init() {
        self.clients = []
        self.status = .pendingSignature
    }
}
