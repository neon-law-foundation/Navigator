import Foundation

/// Structural problems detected when validating a ``Questionnaire`` or
/// ``Workflow``.
///
/// These rules go beyond what the JSON Schema documents under
/// `Sources/NavigatorDAL/Schemas/` can express: schemas guarantee field
/// shapes, but reachability and graph integrity require code.
public enum StateMachineValidationError: Error, Equatable, Sendable {
    /// The state machine has no ``StateName/begin`` state.
    case missingBegin

    /// No transition in the state machine ever lands on ``StateName/end``,
    /// so the machine cannot terminate.
    case endUnreachable

    /// A transition's target is neither a declared state nor
    /// ``StateName/end``.
    case unknownTransitionTarget(
        fromState: StateName,
        condition: Condition,
        target: StateName
    )

    /// The transition map for the given state is empty — every non-``StateName/end``
    /// state must have at least one outgoing edge.
    case deadEndState(StateName)

    /// The workflow state name's ``StateName/kindPrefix`` is not registered
    /// to any ``WorkflowStep`` type. Only ``Workflow/validate()`` emits this.
    case unknownStepPrefix(StateName)
}

extension Questionnaire {
    /// Verifies the structural invariants that JSON Schema cannot express.
    ///
    /// Rules:
    /// - Must contain ``StateName/begin``.
    /// - Some transition must target ``StateName/end``.
    /// - Every transition target must resolve to a declared state or
    ///   ``StateName/end``.
    /// - Every declared non-``StateName/end`` state must have at least one
    ///   outgoing transition.
    public func validate() throws {
        try Self.validateGraph(states: states)
    }
}

extension Workflow {
    /// Verifies the structural invariants the questionnaire validator checks,
    /// plus the workflow-specific rule that every state name's ``StateName/kindPrefix``
    /// resolves to a registered ``WorkflowStep`` via
    /// ``resolveWorkflowStep(stateName:transitions:)``.
    public func validate() throws {
        try Questionnaire.validateGraph(states: states)
        for (name, transitions) in states where !name.isSentinel {
            do {
                _ = try resolveWorkflowStep(
                    stateName: name.rawValue,
                    transitions: transitions.asStringDictionary
                )
            } catch is WorkflowStepError {
                throw StateMachineValidationError.unknownStepPrefix(name)
            }
        }
    }
}

extension Questionnaire {
    /// Shared graph validator used by both ``Questionnaire/validate()`` and
    /// ``Workflow/validate()``. Static because both call sites pass the same
    /// `[StateName: TransitionMap]` storage and the rules are identical.
    fileprivate static func validateGraph(states: [StateName: TransitionMap]) throws {
        guard states[.begin] != nil else {
            throw StateMachineValidationError.missingBegin
        }

        let endIsReachable = states.values.contains { transitions in
            transitions.transitions.values.contains(.end)
        }
        guard endIsReachable else {
            throw StateMachineValidationError.endUnreachable
        }

        for (fromState, transitions) in states where fromState != .end {
            guard !transitions.isEmpty else {
                throw StateMachineValidationError.deadEndState(fromState)
            }
            for (condition, target) in transitions.transitions {
                if target == .end { continue }
                if states[target] == nil {
                    throw StateMachineValidationError.unknownTransitionTarget(
                        fromState: fromState,
                        condition: condition,
                        target: target
                    )
                }
            }
        }
    }
}
