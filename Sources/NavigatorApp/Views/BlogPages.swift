import Elementary
import NavigatorWeb

/// The `/blog` index page.
///
/// Wraps `NavigatorWeb.BlogPostList` so the list rendering itself stays
/// centralised: any visual tweaks to cards land in `NavigatorWeb` and all
/// three web repos pick them up automatically.
struct BlogIndexPage: HTML {
    let brand: any Brand
    let posts: [BlogPost]

    var body: some HTML {
        PageLayout(
            pageTitle: "Blog",
            pageDescription:
                "Updates, notes, and learnings from the Neon Law Foundation's work on access to justice.",
            brand: brand,
            canonicalPath: "/blog"
        ) {
            main(.class("max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                h1(.class("text-4xl font-bold text-gray-900 mb-4")) { "Blog" }
                p(.class("text-lg text-gray-600 mb-10")) {
                    "Short posts on what we are learning as we build tools for access to justice."
                }
                BlogPostList(posts: posts.map { $0.toSummary() }, brand: brand)
            }
        }
    }
}

/// An individual blog post rendered from the parsed Markdown body.
///
/// Markdown is converted via `NavigatorWeb.renderMarkdown`; the returned
/// HTML is inserted through `HTMLRaw`. This is safe because the blog posts
/// are checked into the repository and reviewed before merge.
struct BlogPostPage: HTML {
    let brand: any Brand
    let post: BlogPost

    var body: some HTML {
        PageLayout(
            pageTitle: post.title,
            pageDescription: post.description,
            brand: brand,
            ogType: "article",
            canonicalPath: "/blog/\(post.slug)"
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                article {
                    h1(.class("text-4xl font-bold text-gray-900 mb-3")) { post.title }
                    if !post.author.isEmpty {
                        p(.class("text-sm text-gray-500 mb-8")) { post.author }
                    }
                    div(.class("prose prose-gray max-w-none")) {
                        HTMLRaw(renderMarkdown(post.body))
                    }
                    p(.class("mt-12")) {
                        a(
                            .href("/blog"),
                            .class("font-semibold hover:underline"),
                            .style("color:\(brand.primaryColor)")
                        ) { "\u{2190} Back to the blog" }
                    }
                }
            }
        }
    }
}

extension BlogPost {
    /// Projects this post into the compact `NavigatorWeb.BlogPostSummary`
    /// shape consumed by `BlogPostCard` / `BlogPostList`.
    public func toSummary() -> BlogPostSummary {
        BlogPostSummary(
            slug: slug,
            title: title,
            excerpt: description,
            author: author
        )
    }
}
