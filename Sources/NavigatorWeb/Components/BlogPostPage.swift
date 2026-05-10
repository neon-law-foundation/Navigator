import Elementary

/// Renders a single blog post's full page body — title (and optional
/// author) followed by the markdown body rendered to HTML via the
/// `renderMarkdown(_:)` pipeline.
///
/// The rendered body is embedded via `AnyHTML` (which wraps an
/// `HTMLRaw`) so the visitor's already-escaped output is emitted
/// verbatim instead of double-escaped by Elementary's text rules.
public struct BlogPostPage: HTML {
    public let post: BlogPost
    public let brand: any Brand

    public init(post: BlogPost, brand: any Brand) {
        self.post = post
        self.brand = brand
    }

    public var body: some HTML {
        article(
            .class("max-w-3xl mx-auto px-4 py-8")
        ) {
            header(.class("mb-6")) {
                h1(
                    .class("text-3xl font-bold mb-2"),
                    .style("color:\(brand.primaryColor)")
                ) { post.title }
                if !post.author.isEmpty {
                    p(.class("text-sm text-gray-500")) { post.author }
                }
            }
            div(.class("prose prose-gray max-w-none")) {
                AnyHTML(renderMarkdown(post.body))
            }
        }
    }
}
