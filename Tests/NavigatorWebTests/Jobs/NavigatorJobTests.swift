import Foundation
import Queues
import Testing

@testable import NavigatorWeb

@Suite("NavigatorJob")
struct NavigatorJobTests {

    struct EchoPayload: Codable, Sendable, Equatable {
        let message: String
        let count: Int
    }

    struct EchoJob: NavigatorJob {
        typealias Payload = EchoPayload
        func dequeue(_ context: QueueContext, _ payload: EchoPayload) async throws {}
    }

    struct FastJob: NavigatorJob {
        typealias Payload = EchoPayload
        static let backoffSchedule = ExponentialBackoff(baseSeconds: 1, multiplier: 2)
        func dequeue(_ context: QueueContext, _ payload: EchoPayload) async throws {}
    }

    @Test("Default conformance uses the default exponential schedule")
    func defaultScheduleApplies() {
        let job = EchoJob()
        #expect(job.nextRetryIn(attempt: 1) == 5)
        #expect(job.nextRetryIn(attempt: 3) == 20)
    }

    @Test("Overriding backoffSchedule changes the retry delay")
    func overridingScheduleChangesDelay() {
        let job = FastJob()
        #expect(job.nextRetryIn(attempt: 1) == 1)
        #expect(job.nextRetryIn(attempt: 4) == 8)
    }

    @Test("Codable payloads round-trip through JSON")
    func payloadRoundTrip() throws {
        let original = EchoPayload(message: "hello", count: 7)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EchoPayload.self, from: encoded)
        #expect(decoded == original)
    }
}
