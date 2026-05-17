import Foundation

/// A Fluent-friendly wrapper for a Codable value persisted in a JSONB column.
///
/// Fluent's standard `@Field` binds primitives and Swift arrays using their
/// natural Postgres wire types (`text`, `jsonb[]`, etc.). Pointing those at a
/// `JSONB` column raises `operator does not exist: jsonb = text` or
/// `column is of type jsonb but expression is of type jsonb[]`.
///
/// `JSONStored` works around this by encoding through a *keyed* container.
/// PostgresKit's array-aware encoder treats keyed containers as a signal to
/// abandon native typing and fall back to JSON encoding, which binds as
/// `JSONB`. SQLite uses the same `Codable` path, so the persisted shape is
/// `{"value": <inner JSON>}` on both engines — symmetric encode/decode keeps
/// round-trips clean.
///
/// `ExpressibleByArrayLiteral`, `ExpressibleByDictionaryLiteral`, and
/// `ExpressibleByStringLiteral` conformances are conditional on the inner
/// `Value` so call sites can keep writing `model.field = [x, y, z]` or
/// `model.field = "foo"` without an explicit `JSONStored(...)` wrap.
public struct JSONStored<Value: Codable & Sendable>: Codable, Sendable {
    public var value: Value

    public init(_ value: Value) {
        self.value = value
    }

    private enum CodingKeys: String, CodingKey {
        case value = "v"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try container.decode(Value.self, forKey: .value)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
    }
}

extension JSONStored: Equatable where Value: Equatable {}
extension JSONStored: Hashable where Value: Hashable {}

// MARK: - Literal conveniences

extension JSONStored: ExpressibleByArrayLiteral
where Value: RangeReplaceableCollection & ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Value.Element...) {
        self.value = Value(elements)
    }
}

extension JSONStored: ExpressibleByDictionaryLiteral
where Value: ExpressibleByDictionaryLiteral, Value: _JSONStoredDictionaryInit {
    public init(dictionaryLiteral elements: (Value.Key, Value.Value)...) {
        self.value = Value(_pairs: elements)
    }
}

/// Bridge for synthesising a dictionary from key/value pairs without exposing
/// raw `Dictionary` extensions on the public surface.
public protocol _JSONStoredDictionaryInit: ExpressibleByDictionaryLiteral {
    init(_pairs: [(Key, Value)])
}

extension Dictionary: _JSONStoredDictionaryInit {
    public init(_pairs: [(Key, Value)]) {
        self.init(uniqueKeysWithValues: _pairs)
    }
}

extension JSONStored: ExpressibleByUnicodeScalarLiteral
where Value: ExpressibleByStringLiteral, Value.StringLiteralType == String {
    public init(unicodeScalarLiteral value: String) {
        self.value = Value(stringLiteral: value)
    }
}

extension JSONStored: ExpressibleByExtendedGraphemeClusterLiteral
where Value: ExpressibleByStringLiteral, Value.StringLiteralType == String {
    public init(extendedGraphemeClusterLiteral value: String) {
        self.value = Value(stringLiteral: value)
    }
}

extension JSONStored: ExpressibleByStringLiteral
where Value: ExpressibleByStringLiteral, Value.StringLiteralType == String {
    public init(stringLiteral value: String) {
        self.value = Value(stringLiteral: value)
    }
}
