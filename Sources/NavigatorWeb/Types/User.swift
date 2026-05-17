/// A minimal authenticated-user view-model consumed by header components.
///
/// Components that need to render an authenticated/unauthenticated
/// distinction depend only on these three fields. A richer shape can grow
/// here as the API auth module is wired through to the web layer.
///
/// Named `WebUser` rather than `User` so as not to collide with the
/// `NavigatorDAL.User` Fluent model already re-exported from this module.
public struct WebUser: Sendable, Equatable {
    /// Stable identifier for the user (typically the OIDC subject).
    public let id: String

    /// Human-readable display name shown in headers and account menus.
    public let displayName: String

    /// User's email address.
    public let email: String

    public init(id: String, displayName: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}
