import FluentKit
import Foundation

// Represents a legal entity in the directory
public final class Entity: Model, @unchecked Sendable {
    public static let schema = "entities"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Parent(key: "legal_entity_type_id")
    public var legalEntityType: EntityType

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
