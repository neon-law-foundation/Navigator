import FluentKit
import Foundation

/// The type of shareholder in a `ShareIssuance` — either a natural person or a legal entity.
public enum ShareholderType: String, Codable, CaseIterable, Sendable {
    case person = "person"
    case entity = "entity"
}

/// Records the issuance of shares in an `Entity` to a shareholder.
///
/// The shareholder is polymorphic: it may be either a `Person` or an `Entity`,
/// identified by the `shareholderType` discriminator and `shareholderId` foreign key.
/// An optional `document` blob holds the issuance certificate or agreement.
public final class ShareIssuance: Model, @unchecked Sendable {
    public static let schema = "share_issuances"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "entity_id")
    public var entity: Entity

    @Field(key: "shareholder_type")
    public var shareholderType: ShareholderType

    /// UUID of the shareholder row — points at either `people.id` or `entities.id`
    /// depending on `shareholderType`. Polymorphic FK; no database-level constraint.
    @Field(key: "shareholder_id")
    public var shareholderId: UUID

    @OptionalParent(key: "document_id")
    public var document: Blob?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
