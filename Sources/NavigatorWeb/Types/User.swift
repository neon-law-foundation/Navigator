/// A minimal authenticated-user view-model consumed by header components.
///
/// Introduced in Milestone 2 step 2 of the pure-Swift web stack migration
/// (sagebrush-services/AWS#112) as a temporary stub. The real shape will
/// arrive when the API auth module is wired through to the web layer; in
/// the interim, components that need to render an authenticated/unauthenticated
/// distinction depend only on these three fields.
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
