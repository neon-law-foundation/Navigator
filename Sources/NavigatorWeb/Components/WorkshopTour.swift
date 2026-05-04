// Stub implementation of the workshop guided tour.
//
// The archived NLF/WebComponents library wrapped React Joyride to render
// a spotlight + tooltip product tour with a pulsing beacon and
// localStorage-backed "already seen" tracking. None of that survives the
// pure-Swift cutover: the current component is a server-rendered list
// of step cards with a "Start tour" anchor. Enough to surface the tour
// content in the DOM and be discoverable to search / accessibility tech;
// not enough to actually drive a guided tour.
//
// The full guided-tour UX — overlay, spotlight, beacon, interactive
// next/back/skip controls, and persisted completion state — is
// deferred from M2 and remains a follow-up on this repo.

import Elementary

/// Server-rendered stub for the workshop guided tour.
///
/// Emits an ordered `<ol>` of tour-step cards followed by a "Start tour"
/// anchor pointing at `startPath`. Each card shows the optional title,
/// the step content, and the target CSS selector as a monospace chip so
/// editors and accessibility tools can see which element the full tour
/// will eventually spotlight. No overlay, no spotlight, no beacon, no
/// `localStorage`, no JavaScript — the full interactive guided-tour UX
/// is deferred from M2.
public struct WorkshopTour: HTML {
    public let brandColor: String
    public let steps: [TourStep]
    public let startPath: String
    public let heading: String?

    public init(
        brandColor: String,
        steps: [TourStep],
        startPath: String,
        heading: String? = nil
    ) {
        self.brandColor = brandColor
        self.steps = steps
        self.startPath = startPath
        self.heading = heading
    }

    public var body: some HTML {
        section(
            .class("workshop-tour py-6"),
            .custom(name: "aria-label", value: "Workshop tour")
        ) {
            if let heading {
                h2(
                    .class("text-xl font-semibold mb-4"),
                    .style("color:\(brandColor)")
                ) { heading }
            }
            if steps.isEmpty {
                p(.class("text-gray-500 italic")) { "No tour steps available." }
            } else {
                ol(.class("space-y-4")) {
                    for step in steps {
                        li(
                            .class(
                                "rounded-lg border border-gray-200 bg-white p-4 shadow-sm"
                            )
                        ) {
                            if let title = step.title {
                                h3(
                                    .class("text-sm font-semibold mb-1"),
                                    .style("color:\(brandColor)")
                                ) { title }
                            }
                            p(.class("text-sm text-gray-700 mb-2")) { step.content }
                            p(.class("text-xs text-gray-500")) {
                                "Target: "
                                code(
                                    .class(
                                        "px-1 py-0.5 bg-gray-100 rounded font-mono text-gray-700"
                                    )
                                ) { step.target }
                            }
                        }
                    }
                }
                a(
                    .href(startPath),
                    .class(
                        "inline-block mt-4 px-4 py-2 rounded-lg text-sm font-medium text-white"
                    ),
                    .style("background-color:\(brandColor)")
                ) { "Start tour" }
            }
        }
    }
}
