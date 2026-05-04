import Foundation

/// A step in a template's workflow state machine.
///
/// The concrete type encodes the actor class — no YAML annotation required.
/// The step kind is derived from the state name prefix (the part before `__`),
/// mirroring how questionnaire state names work.
///
/// ## Resolving steps
///
/// Use ``resolveWorkflowStep(stateName:transitions:)`` to map a state name to
/// its typed step at runtime. Unrecognized prefixes throw
/// ``WorkflowStepError/unknownPrefix(_:)`` — all workflow states must map to
/// a registered step type.
///
/// ## Extending the protocol
///
/// New workflow patterns (notarization, signature, payment, court filing, etc.)
/// are added by creating a new conforming type and registering its prefix in
/// ``resolveWorkflowStep(stateName:transitions:)``.
///
/// ## Topics
///
/// ### Protocol requirements
///
/// - ``transitions``
/// - ``actor``
public protocol WorkflowStep: Sendable {

    /// Valid transitions out of this state: condition → next state name.
    var transitions: [String: String] { get }

    /// The actor class expected to trigger transitions out of this state.
    var actor: ActorClass { get }
}

/// Errors thrown when resolving a workflow step.
public enum WorkflowStepError: Error {
    /// The state name prefix is not registered to any ``WorkflowStep`` type.
    case unknownPrefix(String)
}

/// Resolves a workflow state name to its typed ``WorkflowStep``.
///
/// The state name prefix (everything before the first `__`) selects the concrete
/// step type. For example, `"staff_review__for_trustee"` resolves to a
/// ``StaffReviewStep``.
///
/// - Parameters:
///   - stateName: The workflow state name (e.g., `"staff_review__for_trustee"`).
///   - transitions: The transition map for this state from `template.workflow`.
/// - Returns: The typed step for this state.
/// - Throws: ``WorkflowStepError/unknownPrefix(_:)`` if the prefix is not registered.
public func resolveWorkflowStep(
    stateName: String,
    transitions: [String: String]
) throws -> any WorkflowStep {
    let prefix = stateName.components(separatedBy: "__").first ?? stateName
    switch prefix {
    case "BEGIN", "END":
        return SystemStep(transitions: transitions)
    case "staff_review":
        return StaffReviewStep(transitions: transitions)
    case "notarization":
        return NotarizationStep(transitions: transitions)
    case "mailroom_send":
        return MailroomSendStep(transitions: transitions)
    case "mailroom_receive":
        return MailroomReceiveStep(transitions: transitions)
    default:
        throw WorkflowStepError.unknownPrefix(prefix)
    }
}

/// A workflow step driven by the system — used for the `BEGIN` and `END` sentinel states.
///
/// `BEGIN` bootstraps the initial event when a notation is created; `END` marks closure.
/// Both are always `.system` actor, making it clear that no human action triggers these transitions.
public struct SystemStep: WorkflowStep {

    /// Valid transitions out of this state.
    public let transitions: [String: String]

    /// Always `.system` — no human actor is involved in `BEGIN` or `END` transitions.
    public var actor: ActorClass { .system }

    /// Creates a system step with the given transitions.
    public init(transitions: [String: String]) {
        self.transitions = transitions
    }
}

/// A workflow step driven by a staff member.
///
/// Any state whose name begins with `staff_review` (e.g., `staff_review`,
/// `staff_review__for_trustee`) resolves to this type.
/// The actor is always ``ActorClass/staff``.
public struct StaffReviewStep: WorkflowStep {

    /// Valid transitions out of this state.
    public let transitions: [String: String]

    /// Always `.staff` — a staff member drives transitions from this state.
    public var actor: ActorClass { .staff }

    /// Creates a staff review step with the given transitions.
    public init(transitions: [String: String]) {
        self.transitions = transitions
    }
}

/// A workflow step driven by the respondent — used for notarization states.
///
/// Any state whose name begins with `notarization` (e.g., `notarization`,
/// `notarization__for_trustee`) resolves to this type.
/// The actor is always ``ActorClass/respondent``.
public struct NotarizationStep: WorkflowStep {

    /// Valid transitions out of this state.
    public let transitions: [String: String]

    /// Always `.respondent` — the assigned person or entity drives notarization transitions.
    public var actor: ActorClass { .respondent }

    /// Creates a notarization step with the given transitions.
    public init(transitions: [String: String]) {
        self.transitions = transitions
    }
}

/// A workflow step where staff sends mail from the mailroom to an address.
///
/// State names beginning with `mailroom_send` resolve to this type.
public struct MailroomSendStep: WorkflowStep {

    /// Valid transitions out of this state.
    public let transitions: [String: String]

    /// Always `.staff` — a staff member drives mailroom send transitions.
    public var actor: ActorClass { .staff }

    /// Creates a mailroom send step with the given transitions.
    public init(transitions: [String: String]) {
        self.transitions = transitions
    }
}

/// A workflow step where staff logs mail received at the mailroom.
///
/// State names beginning with `mailroom_receive` resolve to this type.
public struct MailroomReceiveStep: WorkflowStep {

    /// Valid transitions out of this state.
    public let transitions: [String: String]

    /// Always `.staff` — a staff member drives mailroom receive transitions.
    public var actor: ActorClass { .staff }

    /// Creates a mailroom receive step with the given transitions.
    public init(transitions: [String: String]) {
        self.transitions = transitions
    }
}
