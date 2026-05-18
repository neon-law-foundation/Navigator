import Elementary

/// A bare `<input type="hidden">` with no surrounding label or chrome.
///
/// Used for values that must round-trip with the form but should not be
/// presented to the operator — typically resource ids, redirect targets,
/// or CSRF-style tokens. ``FormLayout`` already emits the `_method`
/// override input internally; this helper is for everything else.
public struct HiddenField: HTML, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    public var body: some HTML {
        input(.type(.hidden), .name(name), .value(value))
    }
}
