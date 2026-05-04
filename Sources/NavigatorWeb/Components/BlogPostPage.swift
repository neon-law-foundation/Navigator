import Elementary
import Foundation

/// Renders a single blog post's full page body — header (title, date,
/// author, tags) followed by the markdown body rendered to HTML via the
/// M3 `renderMarkdown(_:)` pipeline.
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

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: post.date)
    }

    public var body: some HTML {
        article(
            .class("max-w-3xl mx-auto px-4 py-8")
        ) {
            header(.class("mb-6")) {
                div(.class("flex flex-wrap gap-2 mb-3")) {
                    for tag in post.tags {
                        span(
                            .class("text-xs font-medium px-2 py-1 rounded"),
                            .style(
                                "color:\(brand.primaryColor);background-color:\(brand.primaryColor)14"
                            )
                        ) { tag }
                    }
                }
                h1(
                    .class("text-3xl font-bold mb-2"),
                    .style("color:\(brand.primaryColor)")
                ) { post.title }
                p(.class("text-sm text-gray-500")) {
                    "\(formattedDate) \u{00B7} \(post.author)"
                }
            }
            div(.class("prose prose-gray max-w-none")) {
                AnyHTML(renderMarkdown(post.body))
            }
        }
    }
}
