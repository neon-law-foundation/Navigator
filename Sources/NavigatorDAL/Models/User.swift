import FluentKit
import Foundation

public enum UserRole: String, Codable, CaseIterable, Sendable {
    case client = "client"
    case staff = "staff"
    case admin = "admin"
}

// User accounts for authentication and authorization
public final class User: Model, @unchecked Sendable {
    public static let schema = "users"

    // Unique identifier for the user (UUIDv4)
    @ID(key: .id)
    public var id: UUID?

    // Subject identifier from the x-amzn-oidc-identity header, must be unique
    @OptionalField(key: "sub")
    public var sub: String?

    // User role (client, staff, admin)
    @Field(key: "role")
    public var role: UserRole

    // Timestamp when the user account was created
    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    // Timestamp when the user account was last updated
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    // Reference to the person record in people table
    @Parent(key: "person_id")
    public var person: Person

    public init() {}
}
