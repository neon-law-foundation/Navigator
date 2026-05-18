import Elementary

/// `<a href="...">` styled to look like a ``SubmitButton``.
///
/// Used most often as the "Cancel" sibling of a primary submit button, so
/// the default variant is ``ButtonVariant/secondary``. Pass `.primary` or
/// `.danger` for a styled link that reads as the dominant action — for
/// example a "New project" call-to-action on a list page.
public struct LinkButton: HTML, Sendable {
    public let label: String
    public let href: String
    public let variant: ButtonVariant

    public init(
        _ label: String,
        href: String,
        variant: ButtonVariant = .secondary
    ) {
        self.label = label
        self.href = href
        self.variant = variant
    }

    public var body: some HTML {
        a(.href(href), .class(variant.classes)) { label }
    }
}
