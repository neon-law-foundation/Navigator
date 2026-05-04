import NavigatorWeb
import Vapor
import VaporElementary

/// Registers every public route served by the Neon Law Foundation site.
public func routes(_ app: Application) throws {
    let brand = NLFBrand()

    app.get { _ in
        HTMLResponse { HomePage(brand: brand) }
    }

    app.get("about") { _ in
        HTMLResponse { AboutPage(brand: brand) }
    }

    app.get("education") { _ in
        HTMLResponse { EducationPage(brand: brand) }
    }

    app.get("workshops", "genai-training") { req in
        HTMLResponse {
            WorkshopsPage(brand: brand, materials: req.application.workshopMaterials)
        }
    }

    app.get("workshops", "genai-training", ":slug") { req -> HTMLResponse in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.notFound)
        }
        guard let material = req.application.workshopMaterials.first(where: { $0.slug == slug })
        else {
            throw Abort(.notFound)
        }
        return HTMLResponse {
            WorkshopMaterialPage(brand: brand, material: material)
        }
    }

    // Preserve old bookmarks to the bare /workshops index by redirecting to
    // the canonical workshop landing page.
    app.get("workshops") { req -> Response in
        req.redirect(to: "/workshops/genai-training", redirectType: .permanent)
    }

    app.get("navigator") { _ in
        HTMLResponse { NavigatorPage(brand: brand) }
    }

    app.get("privacy") { _ in
        HTMLResponse { PrivacyPage(brand: brand) }
    }

    app.get("terms") { _ in
        HTMLResponse { TermsPage(brand: brand) }
    }

    app.get("contact") { _ in
        HTMLResponse { ContactPage(brand: brand) }
    }

    app.get("blog") { req in
        let posts = req.application.blogPosts
        return HTMLResponse { BlogIndexPage(brand: brand, posts: posts) }
    }

    app.get("blog", ":slug") { req -> HTMLResponse in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.notFound)
        }
        guard let post = req.application.blogPosts.first(where: { $0.slug == slug }) else {
            throw Abort(.notFound)
        }
        return HTMLResponse { BlogPostPage(brand: brand, post: post) }
    }

    // Health check for CI / load balancers.
    app.get("health") { _ in
        "ok"
    }
}
