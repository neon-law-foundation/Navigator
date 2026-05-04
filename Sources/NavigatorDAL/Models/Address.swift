import FluentKit
import Foundation

/// Represents a physical address linked to either an entity or person in the directory schema.
///
/// The `Address` model stores physical address information for either entities (companies,
/// organizations) or people. Each address must be tied to exactly one entity OR one person,
/// but not both and not neither (XOR constraint).
public final class Address: Model, @unchecked Sendable {
    public static let schema = "addresses"

    @ID(key: .id)
    public var id: UUID?

    @OptionalParent(key: "entity_id")
    public var entity: Entity?

    @OptionalParent(key: "person_id")
    public var person: Person?

    @OptionalParent(key: "mailroom_id")
    public var mailroom: Mailroom?

    @Field(key: "street")
    public var street: String

    @Field(key: "city")
    public var city: String

    @Field(key: "state")
    public var state: String?

    @Field(key: "zip")
    public var zip: String?

    @Field(key: "country")
    public var country: String

    @Field(key: "is_verified")
    public var isVerified: Bool

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
