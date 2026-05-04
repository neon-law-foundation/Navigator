import FluentKit
import Foundation

/// Pivot table linking a ``Retainer`` to a ``Project``.
///
/// A retainer can cover many projects and a project can appear on many retainers.
/// The composite unique constraint on `(retainer_id, project_id)` prevents duplicates.
public final class RetainerProject: Model, @unchecked Sendable {
    public static let schema = "retainer_projects"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "retainer_id")
    public var retainer: Retainer

    @Parent(key: "project_id")
    public var project: Project

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    /// Equal to `insertedAt` for unmodified pivot rows — present so every
    /// table satisfies the `inserted_at` / `updated_at` schema invariant.
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
