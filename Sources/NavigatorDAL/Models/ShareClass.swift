import FluentKit
import Foundation

/// Represents a share class in the equity schema.
///
/// Share classes define different types of shares that can be issued by an entity,
/// with each class having a unique priority level within the entity. The unique
/// compound index on entity_id and priority ensures no two share classes can have
/// the same priority within the same entity.
public final class ShareClass: Model, @unchecked Sendable {
    public static let schema = "share_classes"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Parent(key: "entity_id")
    public var entity: Entity

    @Field(key: "priority")
    public var priority: Int

    @OptionalField(key: "description")
    public var description: String?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
