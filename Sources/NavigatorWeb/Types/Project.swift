/// A minimal project view-model consumed by workshop sidebar components.
///
/// Fields are intentionally minimal: just what `ProjectSidebar` needs to
/// render a link list. A richer shape — with document counts, owners, and
/// status — can grow here as the workshop UI does.
///
/// Named `WebProject` rather than `Project` to avoid collision with the
/// `NavigatorDAL.Project` Fluent model already imported by this module's
/// API handlers. Mirrors the `WebUser`/`NavigatorDAL.User` split.
public struct WebProject: Sendable, Equatable {
    /// Stable identifier for the project; used to match `selectedId`.
    public let id: String

    /// Human-readable display name shown in sidebar entries.
    public let name: String

    /// URL the sidebar link points at.
    public let href: String

    public init(id: String, name: String, href: String) {
        self.id = id
        self.name = name
        self.href = href
    }
}
