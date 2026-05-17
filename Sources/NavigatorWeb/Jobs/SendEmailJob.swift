import Queues

/// Queues job that hands an ``OutboundEmail`` off to an ``EmailSender``.
///
/// The first concrete consumer of ``NavigatorJob``. Default exponential
/// backoff (5s, ×2, no cap) governs retry timing. Total attempt count is
/// set per-dispatch via `JobData.maxRetryCount`; production senders
/// typically pass `maxRetryCount: 5`.
///
/// Brand apps register one instance per process at boot:
///
/// ```swift
/// let job = SendEmailJob(sender: EmailService())
/// app.queues.add(job)
/// ```
///
/// Tests inject a recording or failing ``EmailSender`` to exercise the
/// dispatch path without touching SES.
public struct SendEmailJob: NavigatorJob {
    public typealias Payload = OutboundEmail

    /// The sink used to deliver each dequeued message.
    public let sender: any EmailSender

    public init(sender: any EmailSender) {
        self.sender = sender
    }

    public func dequeue(_ context: QueueContext, _ payload: OutboundEmail) async throws {
        try await sender.send(payload)
    }
}
