/// A Trifecta brand configuration consumed by white-labelled UI components.
///
/// The three concrete brands — `NLFBrand`, `NeonLawBrand`, `SagebrushBrand` —
/// ship in this module. Additional brands can conform by providing their own
/// values; components never branch on brand identity, they read properties.
///
/// Values are intentionally primitive (`String`, `[NavLink]`) so that this
/// module can be used from both server-rendered templates (Elementary) and
/// non-rendering contexts (tests, tooling).
public protocol Brand: Sendable {
    /// Human-readable brand name, e.g. "Neon Law Foundation".
    var name: String { get }

    /// Primary brand color as a hex string including leading `#`.
    var primaryColor: String { get }

    /// Path to the brand logo relative to the site root, e.g. `/logo.svg`.
    var logoPath: String { get }

    /// Links displayed in the brand's top-level site navigation.
    var navLinks: [NavLink] { get }

    /// Links displayed in the brand's site footer.
    var footerLinks: [FooterLink] { get }
}

/// Neon Law Foundation brand — the non-profit that runs AI training workshops.
///
/// `primaryColor` is the cyan-700 teal (`#0e7490`), the deepest shade in the
/// `logo.svg` palette (`rgb(14,116,144)`, `rgb(6,182,212)`, `rgb(103,232,249)`).
/// Every button, tag, and accent on the NLF site renders in this teal so the
/// site reads as a single palette.
public struct NLFBrand: Brand {
    public let name: String = "Neon Law Foundation"
    public let primaryColor: String = "#0e7490"
    public let logoPath: String = "/logo.svg"
    public let navLinks: [NavLink] = [
        NavLink(label: "About", href: "/about"),
        NavLink(label: "Workshops", href: "/workshops"),
        NavLink(label: "Blog", href: "/blog"),
        NavLink(label: "Contact", href: "/contact"),
    ]
    public let footerLinks: [FooterLink] = [
        FooterLink(label: "Privacy", href: "/privacy"),
        FooterLink(label: "Terms", href: "/terms"),
        FooterLink(label: "Contact", href: "/contact"),
    ]

    public init() {}
}

/// Neon Law brand — the law firm at neonlaw.com.
public struct NeonLawBrand: Brand {
    public let name: String = "Neon Law"
    public let primaryColor: String = "#7c3aed"
    public let logoPath: String = "/logo.svg"
    public let navLinks: [NavLink] = [
        NavLink(label: "Estate Planning", href: "/estate-planning"),
        NavLink(label: "Practice Areas", href: "/practice-areas"),
        NavLink(label: "Attorneys", href: "/attorneys"),
        NavLink(label: "Blog", href: "/blog"),
        NavLink(label: "Contact", href: "/contact"),
    ]
    public let footerLinks: [FooterLink] = [
        FooterLink(label: "Privacy", href: "/privacy"),
        FooterLink(label: "Terms", href: "/terms"),
        FooterLink(label: "Contact", href: "/contact"),
    ]

    public init() {}
}

/// Sagebrush brand — corporate services & trust at sagebrush.services.
///
/// Primary color is goldenrod `#DAA520`, matching the pre-cutover
/// `sagebrush-services/Web/src/lib/brand.ts` value used across CTAs,
/// service-card accents, and the contact link.
public struct SagebrushBrand: Brand {
    public let name: String = "Sagebrush"
    public let primaryColor: String = "#DAA520"
    public let logoPath: String = "/logo.svg"
    public let navLinks: [NavLink] = [
        NavLink(label: "Services", href: "/services"),
        NavLink(label: "Trust", href: "/trust"),
        NavLink(label: "Blog", href: "/blog"),
        NavLink(label: "Contact", href: "/contact"),
    ]
    public let footerLinks: [FooterLink] = [
        FooterLink(label: "Privacy", href: "/privacy"),
        FooterLink(label: "Terms", href: "/terms"),
        FooterLink(label: "Contact", href: "/contact"),
    ]

    public init() {}
}
