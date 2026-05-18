import Foundation

/// The typed state machine that drives a template's workflow.
///
/// Shares its wire shape with ``Questionnaire`` — each state name points at a
/// ``TransitionMap`` — but workflow states additionally carry an actor class.
/// The actor is resolved at access time from the state name's
/// ``StateName/kindPrefix`` via
/// ``resolveWorkflowStep(stateName:transitions:)`` so the JSON
/// representation matches the questionnaire format on disk.
public struct Workflow: Sendable, Equatable, Codable, ExpressibleByDictionaryLiteral {
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

    /// Resolves the typed ``WorkflowStep`` for the given state.
    ///
    /// Delegates to the existing
    /// ``resolveWorkflowStep(stateName:transitions:)`` so the dispatch rules
    /// (prefix → concrete step type) stay in one place.
    public func step(at name: StateName) throws -> any WorkflowStep {
        guard let transitions = states[name] else {
            throw WorkflowError.unknownState(name)
        }
        return try resolveWorkflowStep(
            stateName: name.rawValue,
            transitions: transitions.asStringDictionary
        )
    }
}

/// Errors thrown when navigating a ``Workflow``.
public enum WorkflowError: Error, Equatable, Sendable {
    /// No state with the given name exists in this workflow.
    case unknownState(StateName)
}

extension Workflow: _JSONStoredDictionaryInit {
    public init(_pairs: [(StateName, TransitionMap)]) {
        self.states = Dictionary(uniqueKeysWithValues: _pairs)
    }
}
