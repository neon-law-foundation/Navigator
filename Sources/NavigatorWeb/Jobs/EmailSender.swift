/// A sink that can deliver an ``OutboundEmail``.
///
/// Production code uses ``EmailService`` (backed by AWS SES via Soto);
/// tests and CI substitute recording or failing stubs. ``SendEmailJob``
/// depends on the protocol, not the concrete type, so the job logic stays
/// deterministic under test.
public protocol EmailSender: Sendable {
    /// Delivers `message`. Throws on any failure that should trigger a
    /// retry from the Queues worker.
    func send(_ message: OutboundEmail) async throws
}
