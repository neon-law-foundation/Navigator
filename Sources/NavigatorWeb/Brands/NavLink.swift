/// A link displayed in a brand's top-level site navigation.
///
/// `NavLink` is a pure value type consumed by components such as `SiteHeader`.
/// `icon` is optional and is expected to be a brand-agnostic identifier
/// (for example an `lucide`/`heroicons` name) that components may choose to
/// render or ignore.
public struct NavLink: Sendable, Equatable {
    public let label: String
    public let href: String
    public let icon: String?

    public init(label: String, href: String, icon: String? = nil) {
        self.label = label
        self.href = href
        self.icon = icon
    }
}
