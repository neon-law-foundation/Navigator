import Foundation

/// The name of a state in a questionnaire or workflow state machine.
///
/// Wraps a raw string so call sites can write ``begin`` and ``end`` rather than
/// the magic strings `"BEGIN"` and `"END"`. Encoding falls through the raw
/// value, so the on-disk JSON shape is unchanged from the previous
/// string-typed representation.
///
/// State names may carry a "kind prefix" — the substring before the first
/// `"__"` — which workflows use to dispatch to a concrete
/// ``WorkflowStep`` via ``resolveWorkflowStep(stateName:transitions:)``.
public struct StateName: Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The sentinel state that marks the entry point of a state machine.
    public static let begin = StateName(rawValue: "BEGIN")

    /// The sentinel state that marks closure of a state machine.
    public static let end = StateName(rawValue: "END")

    /// The substring before the first `"__"` — or the whole name when no
    /// separator is present. Used by ``resolveWorkflowStep(stateName:transitions:)``
    /// to dispatch to a typed ``WorkflowStep``.
    public var kindPrefix: String {
        rawValue.components(separatedBy: "__").first ?? rawValue
    }

    /// Whether this state is one of the reserved sentinels (``begin`` / ``end``).
    public var isSentinel: Bool {
        self == .begin || self == .end
    }
}

/// The condition label on a transition out of a state.
///
/// Each state's `TransitionMap` keys its outgoing edges by condition. The
/// unconditional edge uses ``unconditional`` (the bare `"_"` label); other
/// transitions can carry application-specific labels (e.g., `"yes"`, `"no"`).
public struct Condition: Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The unconditional transition (`"_"`) — taken when no other condition matches.
    public static let unconditional = Condition(rawValue: "_")
}

/// The outgoing edges of a single state: condition → next state.
///
/// Encoded on disk as a flat string-to-string map so the wire shape matches the
/// pre-typed representation (`{ "_": "person__trustee", "yes": "END" }`).
public struct TransitionMap: Sendable, Equatable, Codable, ExpressibleByDictionaryLiteral {
    public var transitions: [Condition: StateName]

    public init(_ transitions: [Condition: StateName] = [:]) {
        self.transitions = transitions
    }

    public init(dictionaryLiteral elements: (Condition, StateName)...) {
        self.transitions = Dictionary(uniqueKeysWithValues: elements)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: String].self)
        var decoded: [Condition: StateName] = [:]
        for (cond, next) in raw {
            decoded[Condition(rawValue: cond)] = StateName(rawValue: next)
        }
        self.transitions = decoded
    }

    public func encode(to encoder: any Encoder) throws {
        var raw: [String: String] = [:]
        for (cond, next) in transitions {
            raw[cond.rawValue] = next.rawValue
        }
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    public var isEmpty: Bool { transitions.isEmpty }
    public var count: Int { transitions.count }

    public subscript(condition: Condition) -> StateName? {
        get { transitions[condition] }
        set { transitions[condition] = newValue }
    }

    /// Flat `[String: String]` view used by the existing
    /// ``resolveWorkflowStep(stateName:transitions:)`` API.
    public var asStringDictionary: [String: String] {
        var result: [String: String] = [:]
        for (cond, next) in transitions {
            result[cond.rawValue] = next.rawValue
        }
        return result
    }
}
