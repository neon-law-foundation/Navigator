/// Direction half of a JSON:API 1.1 sort field.
public enum SortDirection: Sendable, Equatable {
    case ascending
    case descending

    /// Renders the unicode glyph used by sortable headers to indicate the
    /// active direction. Picked from the BMP so they ship inside HTML
    /// without entity escaping.
    public var arrow: String {
        switch self {
        case .ascending: "\u{2191}"
        case .descending: "\u{2193}"
        }
    }
}

/// Ordered list of sort fields parsed from a JSON:API 1.1 `sort` query
/// parameter.
///
/// The spec at <https://jsonapi.org/format/1.1/#fetching-sorting> states:
///
/// - Fields are comma-separated.
/// - A leading `-` (U+002D) marks a field descending; absent prefix means
///   ascending.
/// - The server **MUST** return `400 Bad Request` when asked to sort by a
///   field it does not support — call ``validated(against:)`` from the
///   route handler to enforce this.
///
/// The value type is immutable so the same instance can be threaded
/// through the view layer without synchronization.
public struct SortSpec: Sendable, Equatable {
    public struct Field: Sendable, Equatable {
        public let key: String
        public let direction: SortDirection

        public init(key: String, direction: SortDirection) {
            self.key = key
            self.direction = direction
        }
    }

    public let fields: [Field]

    public init(fields: [Field] = []) {
        self.fields = fields
    }

    /// Convenience for a single-field spec.
    public static func single(_ key: String, _ direction: SortDirection) -> SortSpec {
        SortSpec(fields: [Field(key: key, direction: direction)])
    }

    /// Parses a raw `?sort=` value into a `SortSpec`.
    ///
    /// Whitespace-only fields and empty fields are dropped. A leading `-`
    /// flips the field to descending. Round-trips with ``encoded``.
    public static func parse(_ raw: String?) -> SortSpec {
        guard let raw, !raw.isEmpty else { return SortSpec() }
        let parts = raw.split(separator: ",", omittingEmptySubsequences: true)
        let fields: [Field] = parts.compactMap { part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.hasPrefix("-") {
                let key = String(trimmed.dropFirst())
                guard !key.isEmpty else { return nil }
                return Field(key: key, direction: .descending)
            }
            return Field(key: trimmed, direction: .ascending)
        }
        return SortSpec(fields: fields)
    }

    /// Re-encodes the spec into a JSON:API `?sort=` value. Empty spec
    /// returns an empty string.
    public var encoded: String {
        fields.map { field in
            field.direction == .descending ? "-\(field.key)" : field.key
        }.joined(separator: ",")
    }

    /// Direction this spec sorts `key` in, or `nil` if `key` is not in the
    /// spec at all.
    public func direction(for key: String) -> SortDirection? {
        fields.first(where: { $0.key == key })?.direction
    }

    /// The sort spec that should result from a user clicking the header
    /// for `key`. Toggle rules:
    ///
    /// - If `key` is the primary sort and ascending, flip to descending.
    /// - If `key` is the primary sort and descending, flip to ascending.
    /// - Otherwise, the new spec is `[key ascending]`.
    ///
    /// Multi-field sorts collapse to single-field on click — shift+click
    /// multi-sort is intentionally not in scope.
    public func toggling(_ key: String) -> SortSpec {
        switch direction(for: key) {
        case .ascending: .single(key, .descending)
        case .descending: .single(key, .ascending)
        case nil: .single(key, .ascending)
        }
    }

    /// Validates every field in the spec against `allowedKeys`. Returns
    /// the spec on success; throws ``SortError/unsupportedField(_:)`` on
    /// the first unknown key.
    ///
    /// Route handlers should call this and translate the error into
    /// `400 Bad Request` to honor the JSON:API 1.1 MUST.
    public func validated(against allowedKeys: Set<String>) throws(SortError) -> SortSpec {
        for field in fields where !allowedKeys.contains(field.key) {
            throw .unsupportedField(field.key)
        }
        return self
    }
}

/// Errors thrown by ``SortSpec/validated(against:)``.
public enum SortError: Error, Equatable, Sendable {
    case unsupportedField(String)
}
