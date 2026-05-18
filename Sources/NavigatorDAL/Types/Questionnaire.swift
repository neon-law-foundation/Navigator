import Foundation

/// The typed state machine that drives a template's questionnaire.
///
/// Each state names a question (or the reserved sentinels ``StateName/begin`` /
/// ``StateName/end``); each value is a ``TransitionMap`` of outgoing edges.
///
/// Encoded on disk as a flat `{ stateName: { condition: nextStateName } }`
/// JSON object, identical to the prior `[String: [String: String]]` shape, so
/// no migration is required on top of ``JSONStored``.
public struct Questionnaire: Sendable, Equatable, Codable, ExpressibleByDictionaryLiteral {
    public var states: [StateName: TransitionMap]

    public init(states: [StateName: TransitionMap] = [:]) {
        self.states = states
    }

    public init(dictionaryLiteral elements: (StateName, TransitionMap)...) {
        self.states = Dictionary(uniqueKeysWithValues: elements)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: TransitionMap].self)
        var decoded: [StateName: TransitionMap] = [:]
        for (name, transitions) in raw {
            decoded[StateName(rawValue: name)] = transitions
        }
        self.states = decoded
    }

    public func encode(to encoder: any Encoder) throws {
        var raw: [String: TransitionMap] = [:]
        for (name, transitions) in states {
            raw[name.rawValue] = transitions
        }
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    public var isEmpty: Bool { states.isEmpty }
    public var count: Int { states.count }

    public subscript(name: StateName) -> TransitionMap? {
        get { states[name] }
        set { states[name] = newValue }
    }

    /// Transitions out of ``StateName/begin``.
    public var begin: TransitionMap? {
        states[.begin]
    }

    /// Transitions out of the given state.
    public func transitions(from state: StateName) -> TransitionMap? {
        states[state]
    }
}

extension Questionnaire: _JSONStoredDictionaryInit {
    public init(_pairs: [(StateName, TransitionMap)]) {
        self.states = Dictionary(uniqueKeysWithValues: _pairs)
    }
}
