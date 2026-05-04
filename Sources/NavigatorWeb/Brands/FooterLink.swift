/// A link displayed in a brand's site footer.
///
/// Mirrors `NavLink` but is kept as its own type so that footer and header
/// collections can evolve independently (for example, footers may group
/// links into columns in a later milestone).
public struct FooterLink: Sendable, Equatable {
    public let label: String
    public let href: String
    public let icon: String?

    public init(label: String, href: String, icon: String? = nil) {
        self.label = label
        self.href = href
        self.icon = icon
    }
}
