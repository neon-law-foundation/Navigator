import Elementary

/// A top-of-form summary listing every validation error a submission
/// produced.
///
/// Per-field error markup still renders next to its input via the
/// `error:` parameter on each field — `FormErrors` is the wide
/// announcement that pairs with it. When the messages array is empty the
/// component renders nothing, so callers can include it unconditionally
/// without guarding on the error count.
///
/// The summary carries `role="alert"` so assistive technology announces
/// the validation outcome on the next page load.
public struct FormErrors: HTML, Sendable {
    public let messages: [String]

    public init(_ messages: [String]) {
        self.messages = messages
    }

    public var body: some HTML {
        if !messages.isEmpty {
            div(
                .class("mb-4 rounded-md border border-red-300 bg-red-50 p-3"),
                .custom(name: "role", value: "alert")
            ) {
                p(.class("text-sm font-medium text-red-800 mb-1")) {
                    messages.count == 1
                        ? "Please fix the error below:"
                        : "Please fix the errors below:"
                }
                ul(.class("list-disc list-inside text-sm text-red-700")) {
                    for message in messages {
                        li { message }
                    }
                }
            }
        }
    }
}
