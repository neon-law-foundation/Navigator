import Testing

@testable import NavigatorWeb

@Suite("SiteHeader")
struct SiteHeaderTests {
    @Test("renders all brand nav links in the desktop nav")
    func rendersBrandNavLinks() {
        let html = SiteHeader(brand: NLFBrand(), authUser: nil).render()

        for link in NLFBrand().navLinks {
            #expect(html.contains(#"href="\#(link.href)""#))
            #expect(html.contains(">\(link.label)<"))
        }
    }

    @Test("renders Sign in link when authUser is nil")
    func rendersSignInWhenUnauthenticated() {
        let html = SiteHeader(brand: NLFBrand(), authUser: nil).render()

        #expect(html.contains(#"href="/login""#))
        #expect(html.contains("Sign in"))
        #expect(!html.contains("Sign out"))
    }

    @Test("renders user display name and Sign out link when authenticated")
    func rendersAccountMenuWhenAuthenticated() {
        let user = WebUser(id: "user-1", displayName: "Ada Lovelace", email: "ada@example.com")
        let html = SiteHeader(brand: NLFBrand(), authUser: user).render()

        #expect(html.contains("Ada Lovelace"))
        #expect(html.contains(#"href="/logout""#))
        #expect(html.contains("Sign out"))
        #expect(!html.contains(#"href="/login""#))
    }

    @Test("includes HTMX-driven mobile nav toggle markup")
    func includesMobileNavToggle() {
        let html = SiteHeader(brand: NLFBrand(), authUser: nil).render()

        #expect(html.contains(#"hx-get="/fragments/mobile-nav""#))
        #expect(html.contains("hx-target=\"#mobile-nav\""))
        #expect(html.contains(#"hx-swap="outerHTML""#))
        #expect(html.contains(#"id="mobile-nav""#))
    }

    @Test("emits the brand name as a data attribute")
    func emitsBrandDataAttribute() {
        let html = SiteHeader(brand: SagebrushBrand(), authUser: nil).render()

        #expect(html.contains(#"data-brand="Sagebrush""#))
    }
}
