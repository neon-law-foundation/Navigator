import Elementary

/// Emphasis level applied to ``SubmitButton`` and ``LinkButton``.
///
/// `.primary` reads as the dominant action on a form, `.secondary` as the
/// cancel / back action that sits next to it, and `.danger` as a
/// destructive action (delete, archive) that should be visually distinct
/// even when it is the only action on the row.
public enum ButtonVariant: Sendable {
    case primary
    case secondary
    case danger

    var classes: String {
        let base =
            "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2"
        let palette: String
        switch self {
        case .primary:
            palette = "bg-indigo-600 text-white hover:bg-indigo-500 focus:ring-indigo-300"
        case .secondary:
            palette = "bg-gray-200 text-gray-800 hover:bg-gray-300 focus:ring-gray-300"
        case .danger:
            palette = "bg-red-600 text-white hover:bg-red-500 focus:ring-red-300"
        }
        return "\(base) \(palette)"
    }
}

/// `<button type="submit">` styled to the chosen ``ButtonVariant``.
public struct SubmitButton: HTML, Sendable {
    public let label: String
    public let variant: ButtonVariant

    public init(_ label: String, variant: ButtonVariant = .primary) {
        self.label = label
        self.variant = variant
    }

    public var body: some HTML {
        button(.type(.submit), .class(variant.classes)) { label }
    }
}
