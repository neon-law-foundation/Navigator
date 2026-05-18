import Foundation
import NavigatorDAL
import Testing

@Suite("State machine validation")
struct StateMachineValidationTests {

    // MARK: - Questionnaire

    @Test("Valid questionnaire passes validation")
    func questionnaireValid() throws {
        let q: Questionnaire = [
            "BEGIN": ["_": "person__trustee"],
            "person__trustee": ["_": "END"],
        ]
        try q.validate()
    }

    @Test("Questionnaire missing BEGIN fails")
    func questionnaireMissingBegin() throws {
        let q: Questionnaire = ["only_state": ["_": "END"]]
        #expect(throws: StateMachineValidationError.missingBegin) {
            try q.validate()
        }
    }

    @Test("Questionnaire that never reaches END fails")
    func questionnaireUnreachableEnd() throws {
        let q: Questionnaire = [
            "BEGIN": ["_": "stuck"],
            "stuck": ["_": "BEGIN"],
        ]
        #expect(throws: StateMachineValidationError.endUnreachable) {
            try q.validate()
        }
    }

    @Test("Questionnaire with unknown transition target fails")
    func questionnaireUnknownTarget() throws {
        let q: Questionnaire = [
            "BEGIN": ["_": "person__trustee"],
            "person__trustee": ["_": "ghost"],
            "another_state": ["_": "END"],
        ]
        do {
            try q.validate()
            Issue.record("Expected unknownTransitionTarget")
        } catch let StateMachineValidationError.unknownTransitionTarget(from, condition, target) {
            #expect(from == StateName(rawValue: "person__trustee"))
            #expect(condition == .unconditional)
            #expect(target == StateName(rawValue: "ghost"))
        }
    }

    @Test("Questionnaire with dead-end state fails")
    func questionnaireDeadEnd() throws {
        let q: Questionnaire = [
            "BEGIN": ["_": "stranded"],
            "stranded": [:],
            "another": ["_": "END"],
        ]
        do {
            try q.validate()
            Issue.record("Expected deadEndState")
        } catch let StateMachineValidationError.deadEndState(state) {
            #expect(state == StateName(rawValue: "stranded"))
        }
    }

    // MARK: - Workflow

    @Test("Valid workflow passes validation")
    func workflowValid() throws {
        let w: Workflow = [
            "BEGIN": ["_": "staff_review"],
            "staff_review": ["_": "notarization__for_trustee"],
            "notarization__for_trustee": ["yes": "END", "_": "staff_review"],
        ]
        try w.validate()
    }

    @Test("Workflow with unknown step prefix fails")
    func workflowUnknownPrefix() throws {
        let w: Workflow = [
            "BEGIN": ["_": "totally_made_up"],
            "totally_made_up": ["_": "END"],
        ]
        do {
            try w.validate()
            Issue.record("Expected unknownStepPrefix")
        } catch let StateMachineValidationError.unknownStepPrefix(state) {
            #expect(state == StateName(rawValue: "totally_made_up"))
        }
    }

    @Test("Workflow inherits graph validation from Questionnaire")
    func workflowGraphValidationInherited() throws {
        // Missing BEGIN should still fire on workflow.
        let w: Workflow = ["staff_review": ["_": "END"]]
        #expect(throws: StateMachineValidationError.missingBegin) {
            try w.validate()
        }
    }

    // MARK: - Schema-level checks (Nevada examples)

    @Test("Nevada trust questionnaire and workflow validate")
    func nevadaTrustValidates() throws {
        let q: Questionnaire = [
            "BEGIN": ["_": "person__trustee"],
            "person__trustee": ["_": "END"],
        ]
        let w: Workflow = [
            "BEGIN": ["_": "staff_review"],
            "staff_review": ["_": "notarization__for_trustee"],
            "notarization__for_trustee": ["yes": "END", "_": "staff_review"],
        ]
        try q.validate()
        try w.validate()
    }
}
