import Elementary
import NavigatorWeb

/// HTML document layout shared by every admin page.
///
/// Distinct from ``PageLayout`` (the public-site document) because admin
/// pages render a fixed sidebar instead of the public site navigation and
/// footer. The `<head>` reuses the same Tailwind CDN reference so the
/// styles stay consistent.
struct AdminPageLayout<Content: HTML>: HTMLDocument {
    let pageTitle: String
    let activeSection: AdminSection
    let brand: any Brand
    @HTMLBuilder var content: () -> Content

    var title: String { "\(pageTitle) - \(brand.name) Admin" }
    var lang: String { "en" }

    var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
        // Admin pages must not surface in search; the rest of the site
        // controls indexability per-page so any robots header inherits.
        meta(.name("robots"), .content("noindex, nofollow"))
        link(.rel(.icon), .href("/favicon.svg"))
        script(.src("https://cdn.tailwindcss.com")) {}
        // HTMX powers progressive enhancements like the live search
        // results swap. Routes detect `HX-Request: true` and respond
        // with a fragment when the browser is asking for one — the same
        // URL still server-renders a full page on a normal navigation.
        script(.src("https://unpkg.com/htmx.org@2.0.4")) {}
        // Alpine powers small interactivity hooks the operator hits
        // with the keyboard — j/k row navigation, Enter to open, "/"
        // to focus the search box, Shift+N to open a "New …" page.
        // Loaded `defer` so it does not block the initial render.
        script(
            .src("https://unpkg.com/alpinejs@3.14.1/dist/cdn.min.js"),
            .custom(name: "defer", value: "defer")
        ) {}
    }

    var body: some HTML {
        div(
            .class("min-h-screen bg-gray-100 flex"),
            .custom(name: "x-data", value: "adminShortcuts")
        ) {
            AdminSidebar(active: activeSection)
            div(.class("flex-1 flex flex-col")) {
                AdminPageHeader(pageTitle: pageTitle, activeSection: activeSection)
                main(.class("flex-1 px-8 py-6")) {
                    content()
                }
            }
            // Alpine "store" expressed as a `x-data` component on the
            // outer admin wrapper. Keeps the wiring in one place so
            // pages just decorate their rows with `data-row-href` and
            // their primary "New …" link with `data-shortcut="new"`.
            script(
                .custom(name: "type", value: "text/javascript")
            ) {
                """
                document.addEventListener('alpine:init', () => {
                    Alpine.data('adminShortcuts', () => ({
                        highlighted: -1,
                        rows() {
                            return Array.from(document.querySelectorAll('tr[data-row-href]'));
                        },
                        move(delta) {
                            const rs = this.rows();
                            if (rs.length === 0) return;
                            this.highlighted = Math.max(0, Math.min(rs.length - 1, this.highlighted + delta));
                            rs.forEach((r, i) => r.classList.toggle('ring-2', i === this.highlighted));
                            rs.forEach((r, i) => r.classList.toggle('ring-indigo-400', i === this.highlighted));
                            rs[this.highlighted]?.scrollIntoView({block: 'nearest'});
                        },
                        open() {
                            const r = this.rows()[this.highlighted];
                            if (r?.dataset.rowHref) window.location = r.dataset.rowHref;
                        },
                        focusSearch() {
                            document.querySelector('input[type=search]')?.focus();
                        },
                        newPage() {
                            const link = document.querySelector('[data-shortcut=\\"new\\"]');
                            if (link) window.location = link.getAttribute('href');
                        },
                    }));
                });
                document.addEventListener('keydown', (e) => {
                    if (e.target.matches('input, textarea, select')) return;
                    const root = document.querySelector('[x-data="adminShortcuts"]');
                    if (!root || !root._x_dataStack) return;
                    const data = root._x_dataStack[0];
                    if (e.key === 'j') { e.preventDefault(); data.move(1); }
                    else if (e.key === 'k') { e.preventDefault(); data.move(-1); }
                    else if (e.key === 'Enter') { data.open(); }
                    else if (e.key === '/') { e.preventDefault(); data.focusSearch(); }
                    else if (e.key === 'N' && e.shiftKey) { e.preventDefault(); data.newPage(); }
                });
                """
            }
        }
    }
}

/// Sticky-feeling header that prints the current section and page title.
/// Pages use the same chrome regardless of resource so the layout cost
/// stays paid once.
struct AdminPageHeader: HTML {
    let pageTitle: String
    let activeSection: AdminSection

    var body: some HTML {
        header(.class("bg-white border-b border-gray-200 px-8 py-4")) {
            p(.class("text-xs uppercase tracking-wide text-gray-500")) {
                activeSection.label
            }
            h1(.class("text-2xl font-bold text-gray-900")) { pageTitle }
        }
    }
}
