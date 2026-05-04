/// A minimal project view-model consumed by workshop sidebar components.
///
/// Introduced in Milestone 2 step 3 of the pure-Swift web stack migration
/// (sagebrush-services/AWS#112) as a temporary stub. The real shape — with
/// document counts, owners, and status — will arrive in a later milestone
/// when the full workshop UI is ported. Fields are intentionally minimal:
/// just what `ProjectSidebar` needs to render a link list.
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
