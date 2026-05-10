import Testing
import Vapor
import VaporTesting

@testable import NavigatorApp

@Suite("Route smoke tests", .serialized)
struct RouteTests {
    @Test("GET / returns 200 and contains the brand marker")
    func homepageReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Neon Law Foundation"))
                    // The unified logo-teal brand color is embedded inline for buttons.
                    #expect(res.body.string.contains("#0e7490"))
                    // The previous green primary color must not appear anywhere.
                    #expect(!res.body.string.contains("#00a651"))
                }
            )
        }
    }

    @Test("GET / hero names the dual mission and links to the workshop")
    func homepageHeroPointsAtWorkshop() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    // Headline and pillar heading (doc-comment contract on HomePage) still render.
                    #expect(res.body.string.contains("Closing the Justice Gap"))
                    #expect(res.body.string.contains("Training Attorneys for Tomorrow"))
                    // Dual-mission subhead replaces the old solo tagline.
                    #expect(res.body.string.contains("Open-source legal software"))
                    // Primary CTA routes to the workshop.
                    #expect(res.body.string.contains("/workshops/genai-training"))
                    #expect(res.body.string.contains("Join the AI Skills Lab"))
                }
            )
        }
    }

    @Test("GET /about returns 200")
    func aboutReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/about",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("About the Foundation"))
                }
            )
        }
    }

    @Test("GET /education returns 200 with all three courses")
    func educationReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/education",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Citation Verification"))
                    #expect(res.body.string.contains("Safe Use of AI Tools"))
                    #expect(res.body.string.contains("AI and Automation for Access to Justice"))
                }
            )
        }
    }

    @Test("GET /workshops/genai-training renders the Claude Code workshop landing page")
    func workshopsLandingReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/workshops/genai-training",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    // Hero.
                    #expect(res.body.string.contains("Claude Code + Twelve Zodiac Lawyers"))
                    // Prerequisites section.
                    #expect(res.body.string.contains("Prerequisites"))
                    // One-hour agenda.
                    #expect(res.body.string.contains("One-Hour Agenda"))
                    #expect(res.body.string.contains("Install Claude Code"))
                    #expect(res.body.string.contains("Twelve Zodiac Lawyers"))
                    // Bloom's Taxonomy objectives.
                    #expect(res.body.string.contains("Learning Objectives"))
                    #expect(res.body.string.contains("Bloom"))
                    // Download cards link to the per-material copy-paste pages.
                    #expect(
                        res.body.string.contains(
                            "/workshops/genai-training/readme"
                        )
                    )
                    #expect(
                        res.body.string.contains(
                            "/workshops/genai-training/personas"
                        )
                    )
                    #expect(
                        res.body.string.contains(
                            "/workshops/genai-training/operating-agreement"
                        )
                    )
                }
            )
        }
    }

    @Test("GET /workshops 301-redirects to the canonical workshop landing page")
    func workshopsBareSlugRedirects() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/workshops",
                afterResponse: { res async in
                    // `.permanent` redirect type → HTTP 301 Moved Permanently.
                    #expect(res.status == .movedPermanently)
                    #expect(
                        res.headers.first(name: .location) == "/workshops/genai-training"
                    )
                }
            )
        }
    }

    @Test("GET /workshops/genai-training/readme renders the copy-card runbook page")
    func workshopRunbookMaterialPageReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/workshops/genai-training/readme",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Participant runbook"))
                    // Copy button marker and the raw-download link to FileMiddleware.
                    #expect(res.body.string.contains("data-copy-button=\"readme\""))
                    #expect(res.body.string.contains("data-copy-source=\"readme\""))
                    #expect(
                        res.body.string.contains(
                            "/workshops/claude-code-zodiac/README.md"
                        )
                    )
                    // The inline clipboard script wires up the button.
                    #expect(res.body.string.contains("navigator.clipboard.writeText"))
                    // Back link returns to the workshop landing page.
                    #expect(res.body.string.contains("/workshops/genai-training"))
                    // Rendered Markdown body shows the runbook heading.
                    #expect(res.body.string.contains("Participant Runbook"))
                }
            )
        }
    }

    @Test("GET /workshops/genai-training/personas renders the copy-card personas page")
    func workshopPersonasMaterialPageReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/workshops/genai-training/personas",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Twelve persona prompts"))
                    #expect(res.body.string.contains("data-copy-button=\"personas\""))
                    #expect(res.body.string.contains("data-copy-source=\"personas\""))
                    #expect(
                        res.body.string.contains(
                            "/workshops/claude-code-zodiac/personas.md"
                        )
                    )
                }
            )
        }
    }

    @Test("GET /workshops/genai-training/operating-agreement renders the copy-card OA page")
    func workshopOperatingAgreementMaterialPageReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/workshops/genai-training/operating-agreement",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Sample operating agreement"))
                    #expect(res.body.string.contains("data-copy-button=\"operating-agreement\""))
                    #expect(res.body.string.contains("data-copy-source=\"operating-agreement\""))
                    #expect(
                        res.body.string.contains(
                            "/workshops/claude-code-zodiac/operating-agreement.md"
                        )
                    )
                }
            )
        }
    }

    @Test("GET /workshops/genai-training/nope returns 404 for an unknown slug")
    func workshopUnknownSlugReturns404() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/workshops/genai-training/nope",
                afterResponse: { res async in
                    #expect(res.status == .notFound)
                }
            )
        }
    }

    @Test("GET /workshops/claude-code-zodiac/README.md serves the participant runbook")
    func workshopRunbookIsServed() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/workshops/claude-code-zodiac/README.md",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Participant Runbook"))
                    #expect(res.body.string.contains("Install Claude Code"))
                }
            )
        }
    }

    @Test("GET /navigator returns 200 with core components")
    func navigatorReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/navigator",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Templates"))
                    #expect(res.body.string.contains("Notations"))
                    #expect(res.body.string.contains("State Machines"))
                }
            )
        }
    }

    @Test("GET /privacy returns 200")
    func privacyReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/privacy",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Privacy Policy"))
                }
            )
        }
    }

    @Test("GET /terms returns 200")
    func termsReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/terms",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Terms of Service"))
                }
            )
        }
    }

    @Test("GET /contact returns 200")
    func contactReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/contact",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("support@neonlaw.org"))
                }
            )
        }
    }

    @Test("GET /health returns ok")
    func healthReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/health",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                    #expect(res.body.string == "ok")
                }
            )
        }
    }
}
