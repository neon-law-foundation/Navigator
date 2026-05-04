import Elementary
import Foundation
import NavigatorWeb

/// Renders a single Claude Code workshop handout with a copy-to-clipboard
/// card above the rendered Markdown body.
///
/// The copy card mimics the Claude Code documentation pattern: a rounded
/// container, the filename on the left, and a clipboard button on the
/// right that flips to a checkmark on success. A "Download .md" link sits
/// beside the button for participants who prefer `curl`/`wget` — the raw
/// source is served unchanged by ``FileMiddleware`` from `Public/`.
struct WorkshopMaterialPage: HTML {
    let brand: any Brand
    let material: WorkshopMaterial

    var body: some HTML {
        PageLayout(
            pageTitle: material.title,
            pageDescription: material.description,
            brand: brand
        ) {
            main(.class("max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16")) {
                p(.class("mb-2")) {
                    a(
                        .href("/workshops/genai-training"),
                        .class("text-sm font-semibold hover:underline"),
                        .style("color:\(brand.primaryColor)")
                    ) { "\u{2190} Back to the workshop" }
                }
                h1(.class("text-4xl font-bold text-gray-900 mb-3")) { material.title }
                p(.class("text-lg text-gray-600 mb-8")) { material.description }

                CopyCard(brand: brand, material: material)

                article(.class("prose prose-gray max-w-none")) {
                    HTMLRaw(renderMarkdown(material.rawMarkdown))
                }
            }
            CopyCardScript()
        }
    }
}

/// The Claude-Code-style copy card rendered above the material body.
private struct CopyCard: HTML {
    let brand: any Brand
    let material: WorkshopMaterial

    var body: some HTML {
        div(
            .class("border border-gray-200 rounded-xl overflow-hidden mb-10 shadow-sm"),
            .custom(name: "data-copy-card", value: material.slug)
        ) {
            // Top bar: filename on the left, copy button + download on the right.
            div(
                .class(
                    "flex items-center justify-between bg-gray-50 border-b border-gray-200 "
                        + "px-4 py-3"
                )
            ) {
                span(
                    .class(
                        "font-mono text-sm text-gray-700 truncate pr-3"
                    )
                ) { filename }

                div(.class("flex items-center gap-3 shrink-0")) {
                    a(
                        .href(material.rawURL),
                        .class(
                            "text-sm font-semibold hover:underline"
                        ),
                        .style("color:\(brand.primaryColor)"),
                        .custom(name: "download", value: filename)
                    ) { "Download .md" }

                    button(
                        .custom(name: "type", value: "button"),
                        .class(
                            "inline-flex items-center gap-2 px-3 py-1.5 rounded-md "
                                + "text-sm font-semibold text-white"
                        ),
                        .style("background-color:\(brand.primaryColor)"),
                        .custom(name: "data-copy-button", value: material.slug),
                        .custom(name: "aria-label", value: "Copy \(filename) to clipboard")
                    ) {
                        // The two icons and the label are swapped in-place by the
                        // inline script when a click succeeds. Keep both glyphs
                        // in the DOM so the swap is a visibility toggle rather
                        // than an insertion, which is slightly less janky.
                        span(.custom(name: "data-copy-icon", value: "idle")) {
                            ClipboardIcon()
                        }
                        span(
                            .class("hidden"),
                            .custom(name: "data-copy-icon", value: "done")
                        ) {
                            CheckIcon()
                        }
                        span(.custom(name: "data-copy-label", value: "")) { "Copy" }
                    }
                }
            }

            // Raw source in a pre-formatted block, embedded verbatim so the
            // clipboard button can read it straight from the DOM.
            pre(
                .class(
                    "overflow-x-auto text-xs leading-relaxed bg-white px-4 py-4 max-h-64 "
                        + "font-mono text-gray-800"
                ),
                .custom(name: "data-copy-source", value: material.slug)
            ) {
                material.rawMarkdown
            }
        }
    }

    private var filename: String {
        // rawURL ends with "/<filename>.md"; keep just the filename for display.
        URL(string: material.rawURL)?.lastPathComponent ?? material.slug
    }
}

private struct ClipboardIcon: HTML {
    var body: some HTML {
        HTMLRaw(
            #"<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" "#
                + #"viewBox="0 0 24 24" fill="none" stroke="currentColor" "#
                + #"stroke-width="2" stroke-linecap="round" stroke-linejoin="round" "#
                + #"aria-hidden="true">"#
                + #"<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>"#
                + #"<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>"#
                + "</svg>"
        )
    }
}

private struct CheckIcon: HTML {
    var body: some HTML {
        HTMLRaw(
            #"<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" "#
                + #"viewBox="0 0 24 24" fill="none" stroke="currentColor" "#
                + #"stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" "#
                + #"aria-hidden="true">"#
                + #"<polyline points="20 6 9 17 4 12"/>"#
                + "</svg>"
        )
    }
}

/// Tiny inline script that wires every `data-copy-button` on the page to
/// copy the adjacent `data-copy-source` content and briefly swap its icon.
private struct CopyCardScript: HTML {
    var body: some HTML {
        script(.type("text/javascript")) {
            HTMLRaw(
                """
                (function() {
                  var buttons = document.querySelectorAll('[data-copy-button]');
                  buttons.forEach(function(btn) {
                    btn.addEventListener('click', function() {
                      var slug = btn.getAttribute('data-copy-button');
                      var source = document.querySelector(
                        '[data-copy-source="' + slug + '"]'
                      );
                      if (!source) return;
                      var text = source.textContent || '';
                      navigator.clipboard.writeText(text).then(function() {
                        var idle = btn.querySelector('[data-copy-icon="idle"]');
                        var done = btn.querySelector('[data-copy-icon="done"]');
                        var label = btn.querySelector('[data-copy-label]');
                        if (idle) idle.classList.add('hidden');
                        if (done) done.classList.remove('hidden');
                        if (label) label.textContent = 'Copied';
                        setTimeout(function() {
                          if (idle) idle.classList.remove('hidden');
                          if (done) done.classList.add('hidden');
                          if (label) label.textContent = 'Copy';
                        }, 1600);
                      });
                    });
                  });
                })();
                """
            )
        }
    }
}
