import FluentKit
import Foundation

/// Represents any client-provided or generated file associated with a legal matter.
///
/// A `Document` is owned by a `Project` and backed by a `Blob` that holds the
/// object storage URL. It carries a human-readable `title` to distinguish files
/// within a project.
public final class Document: Model, @unchecked Sendable {
    public static let schema = "documents"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "project_id")
    public var project: Project

    @Parent(key: "blob_id")
    public var blob: Blob

    @Field(key: "title")
    public var title: String

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
