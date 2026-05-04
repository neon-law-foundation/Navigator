import Testing

@testable import NavigatorWeb

@Suite("SiteFooter")
struct SiteFooterTests {
    @Test("renders NLF brand with footer links and copyright year")
    func rendersNLFBrand() {
        let html = SiteFooter(brand: NLFBrand(), year: 2026).render()

        let expected = """
            <footer class="bg-gray-900 text-gray-300 py-8" data-brand="Neon Law Foundation">\
            <div class="max-w-7xl mx-auto px-4">\
            <div class="flex flex-col md:flex-row justify-between items-center gap-4">\
            <p class="text-sm">© 2026 Neon Law Foundation. All rights reserved.</p>\
            <nav class="flex gap-4">\
            <a href="/privacy" class="text-sm hover:text-white transition-colors">Privacy</a>\
            <a href="/terms" class="text-sm hover:text-white transition-colors">Terms</a>\
            <a href="/contact" class="text-sm hover:text-white transition-colors">Contact</a>\
            </nav></div></div></footer>
            """

        #expect(html == expected)
    }

    @Test("reflects the brand name in the data attribute and copyright")
    func reflectsBrandName() {
        let html = SiteFooter(brand: NeonLawBrand(), year: 2030).render()

        #expect(html.contains(#"data-brand="Neon Law""#))
        #expect(html.contains("© 2030 Neon Law. All rights reserved."))
    }

    @Test("renders Sagebrush brand footer links")
    func rendersSagebrushLinks() {
        let html = SiteFooter(brand: SagebrushBrand(), year: 2026).render()

        #expect(html.contains(#"<a href="/privacy""#))
        #expect(html.contains(#"<a href="/terms""#))
        #expect(html.contains(#"<a href="/contact""#))
    }
}
