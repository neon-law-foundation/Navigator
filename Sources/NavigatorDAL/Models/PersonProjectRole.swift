import FluentKit
import Foundation

/// Role a person holds on a specific project.
public enum ProjectRole: String, Codable, CaseIterable, Sendable {
    case staff = "staff"
    case client = "client"
}

/// Maps a person to a project with a specific role (staff or client).
///
/// Composite unique constraint ensures each person has at most one role per project.
public final class PersonProjectRole: Model, @unchecked Sendable {
    public static let schema = "person_project_roles"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "person_id")
    public var person: Person

    @Parent(key: "project_id")
    public var project: Project

    @Field(key: "role")
    public var role: ProjectRole

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
