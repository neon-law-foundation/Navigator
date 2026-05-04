import Elementary

/// Renders a workshop chat transcript plus a send form driven entirely by
/// HTMX — zero client-side JavaScript.
///
/// The full message history is rendered server-side into `#chat-log`.
/// Submitting the textarea posts to `sendPath` via
/// `hx-post="{sendPath}" hx-target="#chat-log" hx-swap="beforeend"` so the
/// server appends the rendered message pair to the log on each round-trip.
/// The `contextFileIds` are emitted as hidden inputs so the server receives
/// the same context the visitor sees in the header chip.
///
/// User messages render right-aligned with the brand color as the bubble
/// background; assistant messages render left-aligned in a neutral gray
/// bubble. When an assistant message has citations, the citation list is
/// wrapped in a native `<details>/<summary>` element — callers get an
/// accessible expand/collapse affordance without any JavaScript.
///
/// A disabled chat (`disabled: true`) grays the textarea and send button
/// for anonymous read-only previews; the transcript still renders.
public struct ChatInterface: HTML {
    public let brandColor: String
    public let contextFileIds: [String]
    public let messages: [ChatMessage]
    public let sendPath: String
    public let disabled: Bool

    public init(
        brandColor: String,
        contextFileIds: [String],
        messages: [ChatMessage],
        sendPath: String,
        disabled: Bool = false
    ) {
        self.brandColor = brandColor
        self.contextFileIds = contextFileIds
        self.messages = messages
        self.sendPath = sendPath
        self.disabled = disabled
    }

    public var body: some HTML {
        div(.class("flex flex-col h-full bg-white")) {
            div(
                .class(
                    "px-4 py-2 border-b border-gray-200 flex items-center gap-2 flex-shrink-0 text-xs text-gray-500"
                )
            ) {
                span { "\(contextFileIds.count) \(contextFileIds.count == 1 ? "file" : "files") in context" }
            }
            div(
                .id("chat-log"),
                .class("flex-1 overflow-y-auto px-4 py-4 space-y-4")
            ) {
                if messages.isEmpty {
                    p(.class("text-center text-gray-400 text-sm mt-8")) {
                        "Ask a question about your documents."
                    }
                } else {
                    for message in messages {
                        ChatMessageRow(message: message, brandColor: brandColor)
                    }
                }
            }
            form(
                .class("border-t border-gray-200 px-4 py-3 flex-shrink-0"),
                .custom(name: "hx-post", value: sendPath),
                .custom(name: "hx-target", value: "#chat-log"),
                .custom(name: "hx-swap", value: "beforeend")
            ) {
                for fileId in contextFileIds {
                    input(
                        .type(.hidden),
                        .name("fileIds"),
                        .value(fileId)
                    )
                }
                div(.class("flex gap-2 items-end")) {
                    if disabled {
                        textarea(
                            .name("prompt"),
                            .class(
                                "flex-1 resize-none rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-800 placeholder-gray-400 focus:outline-none focus:ring-2 transition-shadow disabled:bg-gray-50 disabled:text-gray-400"
                            ),
                            .custom(name: "rows", value: "3"),
                            .custom(name: "placeholder", value: "Ask a question\u{2026}"),
                            .custom(name: "disabled", value: "disabled")
                        ) {}
                    } else {
                        textarea(
                            .name("prompt"),
                            .class(
                                "flex-1 resize-none rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-800 placeholder-gray-400 focus:outline-none focus:ring-2 transition-shadow disabled:bg-gray-50 disabled:text-gray-400"
                            ),
                            .custom(name: "rows", value: "3"),
                            .custom(name: "placeholder", value: "Ask a question\u{2026}")
                        ) {}
                    }
                    if disabled {
                        button(
                            .type(.submit),
                            .class(
                                "flex-shrink-0 text-white px-4 py-2 rounded-lg text-sm font-medium transition-opacity disabled:opacity-50"
                            ),
                            .style("background-color:\(brandColor)"),
                            .custom(name: "aria-label", value: "Send message"),
                            .custom(name: "disabled", value: "disabled")
                        ) { "Send" }
                    } else {
                        button(
                            .type(.submit),
                            .class(
                                "flex-shrink-0 text-white px-4 py-2 rounded-lg text-sm font-medium transition-opacity disabled:opacity-50"
                            ),
                            .style("background-color:\(brandColor)"),
                            .custom(name: "aria-label", value: "Send message")
                        ) { "Send" }
                    }
                }
            }
        }
    }
}

/// A single message bubble — factored out for readability, not reuse.
/// The `@HTMLBuilder` body keeps user and assistant branches close to their
/// shared layout without duplicating the outer flex wrapper.
private struct ChatMessageRow: HTML {
    let message: ChatMessage
    let brandColor: String

    var body: some HTML {
        let isUser = message.role == .user
        div(
            .class("flex flex-col gap-1 \(isUser ? "items-end" : "items-start")")
        ) {
            bubble(isUser: isUser)
            if !isUser && !message.citations.isEmpty {
                details(.class("w-full max-w-prose")) {
                    summary(
                        .class("text-xs cursor-pointer mt-1"),
                        .style("color:\(brandColor)")
                    ) {
                        "\(message.citations.count) \(message.citations.count == 1 ? "citation" : "citations")"
                    }
                    ul(.class("mt-2 space-y-2")) {
                        for citation in message.citations {
                            li {
                                div(
                                    .class(
                                        "bg-gray-50 rounded-md px-3 py-2 text-xs text-gray-600 border-l-2"
                                    ),
                                    .style("border-color:\(brandColor)")
                                ) {
                                    p(
                                        .class("font-medium mb-1"),
                                        .style("color:\(brandColor)")
                                    ) { citation.documentName }
                                    p(.class("italic")) {
                                        "\u{201C}\(citation.passage)\u{201D}"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    private func bubble(isUser: Bool) -> some HTML {
        if isUser {
            div(
                .class("max-w-prose rounded-lg px-4 py-3 text-sm leading-relaxed text-white"),
                .style("background-color:\(brandColor)")
            ) { message.content }
        } else {
            div(
                .class(
                    "max-w-prose rounded-lg px-4 py-3 text-sm leading-relaxed bg-gray-100 text-gray-800"
                )
            ) { message.content }
        }
    }
}
