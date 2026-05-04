import FluentKit
import Foundation

/// Projects that group assigned notations together.
///
/// This model represents projects in the matters schema, each with a unique codename
/// and containing multiple assigned notations. Projects serve as containers to organize
/// related legal work and notation assignments.
public final class Project: Model, @unchecked Sendable {
    public static let schema = "projects"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "codename")
    public var codename: String

    @OptionalField(key: "title")
    public var title: String?

    @OptionalField(key: "status")
    public var status: ProjectStatus?

    @OptionalField(key: "project_type")
    public var projectType: ProjectType?

    @Children(for: \.$project)
    public var gitRepositories: [GitRepository]

    @Children(for: \.$project)
    public var documents: [Document]

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
