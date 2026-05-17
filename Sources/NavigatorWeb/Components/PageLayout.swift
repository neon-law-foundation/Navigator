import Elementary

/// Full-page layout shared by every brand site.
///
/// `PageLayout` is an `HTMLDocument` that emits the standard document chrome
/// — doctype, `<html>`, `<head>` (title, charset, viewport, favicon, Tailwind
/// CDN), and `<body>` — and renders caller-supplied content inside `<body>`.
///
/// Brand-aware pages wrap their content in `PageLayout`; composite layouts
/// in this module (`BlogIndexLayout`, `BlogPostLayout`) also delegate to
/// `PageLayout.sharedHead(brand:)` so every entry point emits the same
/// `<head>` markup.
///
/// Tailwind is loaded via the Play CDN (`<script src="https://cdn.tailwindcss.com">`).
/// This is an interim fix — a build-time compiled stylesheet served from
/// `Public/app.css` is a longer-term task tracked in issue #63.
public struct PageLayout<Body: HTML>: HTMLDocument {
    public let title: String
    public let brand: any Brand
    @HTMLBuilder public let pageBody: Body

    public init(
        title: String,
        brand: any Brand,
        @HTMLBuilder body: () -> Body
    ) {
        self.title = title
        self.brand = brand
        self.pageBody = body()
    }

    /// Shared `<head>` children emitted by every layout in this module.
    ///
    /// Exposed as a static builder so composite layouts (`BlogIndexLayout`,
    /// `BlogPostLayout`) can include the same chrome without composing an
    /// entire `PageLayout` instance.
    @HTMLBuilder
    public static func sharedHead(brand: any Brand) -> some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
        link(.rel("icon"), .href(brand.logoPath))
        // Interim: Tailwind 4 Play CDN. Compiled stylesheet tracked in #63.
        script(.src("https://cdn.tailwindcss.com")) {}
    }

    public var head: some HTML {
        PageLayout<EmptyHTML>.sharedHead(brand: brand)
    }

    public var body: some HTML {
        pageBody
    }
}

extension PageLayout: Sendable where Body: Sendable {}
