import Foundation
import Logging
import Queues
import Testing
import Vapor

@testable import NavigatorWeb

@Suite("SendEmailJob")
struct SendEmailJobTests {

    actor RecordingSender: EmailSender {
        private(set) var sent: [OutboundEmail] = []

        func send(_ message: OutboundEmail) async throws {
            sent.append(message)
        }
    }

    struct FailingSender: EmailSender {
        struct Boom: Error, Equatable {}
        func send(_ message: OutboundEmail) async throws {
            throw Boom()
        }
    }

    @Test("Payload round-trips through Codable with and without replyTo")
    func payloadRoundTrip() throws {
        let withReply = OutboundEmail(
            to: "alice@example.com",
            from: "no-reply@sagebrush.services",
            subject: "Hi",
            body: "Body",
            replyTo: "ops@sagebrush.services"
        )
        let withoutReply = OutboundEmail(
            to: "bob@example.com",
            from: "no-reply@sagebrush.services",
            subject: "Hi",
            body: "Body"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        #expect(try decoder.decode(OutboundEmail.self, from: encoder.encode(withReply)) == withReply)
        #expect(
            try decoder.decode(OutboundEmail.self, from: encoder.encode(withoutReply)) == withoutReply
        )
    }

    @Test("Happy path: dequeue forwards the message to the sender")
    func happyPath() async throws {
        let recorder = RecordingSender()
        let job = SendEmailJob(sender: recorder)
        let message = OutboundEmail(
            to: "alice@example.com",
            from: "no-reply@sagebrush.services",
            subject: "Welcome",
            body: "Thanks for signing up."
        )

        try await withQueueContext { context in
            try await job.dequeue(context, message)
        }

        let sent = await recorder.sent
        #expect(sent == [message])
    }

    @Test("Retry path: dequeue rethrows so Queues schedules another attempt")
    func retryOnFailure() async throws {
        let job = SendEmailJob(sender: FailingSender())
        let message = OutboundEmail(
            to: "alice@example.com",
            from: "no-reply@sagebrush.services",
            subject: "Welcome",
            body: "Body"
        )

        try await withQueueContext { context in
            await #expect(throws: FailingSender.Boom.self) {
                try await job.dequeue(context, message)
            }
        }
    }

    @Test("nextRetryIn schedule matches the default exponential backoff")
    func backoffMatchesDefault() {
        let job = SendEmailJob(sender: RecordingSender())
        #expect(job.nextRetryIn(attempt: 1) == 5)
        #expect(job.nextRetryIn(attempt: 2) == 10)
        #expect(job.nextRetryIn(attempt: 3) == 20)
        #expect(job.nextRetryIn(attempt: 4) == 40)
        #expect(job.nextRetryIn(attempt: 5) == 80)
    }

    private func withQueueContext<T: Sendable>(
        _ body: (QueueContext) async throws -> T
    ) async throws -> T {
        let app = try await Application.make(.testing)
        do {
            let context = QueueContext(
                queueName: .default,
                configuration: app.queues.configuration,
                application: app,
                logger: Logger(label: "send-email-job-tests"),
                on: app.eventLoopGroup.next()
            )
            let result = try await body(context)
            try await app.asyncShutdown()
            return result
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }
}
