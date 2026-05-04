import Testing

@testable import NavigatorWeb

@Suite("ExponentialBackoff")
struct ExponentialBackoffTests {

    @Test("Default schedule doubles from a five-second base")
    func defaultScheduleDoubles() {
        let schedule = ExponentialBackoff.default
        #expect(schedule.delaySeconds(forAttempt: 1) == 5)
        #expect(schedule.delaySeconds(forAttempt: 2) == 10)
        #expect(schedule.delaySeconds(forAttempt: 3) == 20)
        #expect(schedule.delaySeconds(forAttempt: 4) == 40)
        #expect(schedule.delaySeconds(forAttempt: 5) == 80)
    }

    @Test("Non-positive attempts return zero")
    func nonPositiveAttempts() {
        let schedule = ExponentialBackoff.default
        #expect(schedule.delaySeconds(forAttempt: 0) == 0)
        #expect(schedule.delaySeconds(forAttempt: -3) == 0)
    }

    @Test("Custom base and multiplier are honoured")
    func customBaseAndMultiplier() {
        let schedule = ExponentialBackoff(baseSeconds: 2, multiplier: 3)
        #expect(schedule.delaySeconds(forAttempt: 1) == 2)
        #expect(schedule.delaySeconds(forAttempt: 2) == 6)
        #expect(schedule.delaySeconds(forAttempt: 3) == 18)
        #expect(schedule.delaySeconds(forAttempt: 4) == 54)
    }

    @Test("Cap clamps later attempts to the configured maximum")
    func capClampsLaterAttempts() {
        let schedule = ExponentialBackoff(baseSeconds: 5, multiplier: 2, maxDelaySeconds: 30)
        #expect(schedule.delaySeconds(forAttempt: 1) == 5)
        #expect(schedule.delaySeconds(forAttempt: 2) == 10)
        #expect(schedule.delaySeconds(forAttempt: 3) == 20)
        #expect(schedule.delaySeconds(forAttempt: 4) == 30)
        #expect(schedule.delaySeconds(forAttempt: 5) == 30)
        #expect(schedule.delaySeconds(forAttempt: 50) == 30)
    }

    @Test("Overflowing growth without a cap saturates at Int.max")
    func overflowSaturates() {
        let schedule = ExponentialBackoff(baseSeconds: 1_000_000, multiplier: 1_000)
        #expect(schedule.delaySeconds(forAttempt: 10) == .max)
    }

    @Test("Default schedule equals the explicit default initializer")
    func defaultMatchesExplicitInit() {
        #expect(ExponentialBackoff.default == ExponentialBackoff())
    }
}
