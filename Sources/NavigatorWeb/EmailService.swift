import Foundation
import Logging
import SotoSES

private let logger = Logger(label: "email-service")

/// Sends email via AWS SES.
///
/// Uses `AWS_ENDPOINT_URL` when set to route requests to LocalStack for
/// local development. When unset, routes through the dual-stack
/// `email.${region}.api.aws` endpoint so SES traffic resolves over IPv6 from
/// VPCs whose private subnets egress via an Egress-Only Internet Gateway.
/// Conforms to ``EmailSender`` so ``SendEmailJob`` and other callers can
/// substitute recording stubs in tests.
public struct EmailService: EmailSender {
    /// Dual-stack SES endpoint for `us-west-2`. The classic
    /// `email.us-west-2.amazonaws.com` host has no AAAA record; VPCs whose
    /// private subnets egress only via an Egress-Only Internet Gateway cannot
    /// reach it. The unified `.api.aws` domain serves AAAA.
    static let defaultEndpoint = "https://email.us-west-2.api.aws"

    public init() {}

    public func send(_ message: OutboundEmail) async throws {
        let endpoint =
            ProcessInfo.processInfo.environment["AWS_ENDPOINT_URL"]
            ?? Self.defaultEndpoint
        let awsClient = AWSClient()
        let ses = SES(client: awsClient, endpoint: endpoint)
        let request = SES.SendEmailRequest(
            destination: .init(toAddresses: [message.to]),
            message: .init(
                body: .init(text: .init(charset: "UTF-8", data: message.body)),
                subject: .init(charset: "UTF-8", data: message.subject)
            ),
            replyToAddresses: message.replyTo.map { [$0] },
            source: message.from
        )
        var sendError: (any Error)?
        do {
            _ = try await ses.sendEmail(request)
        } catch {
            sendError = error
        }
        try await awsClient.shutdown()
        if let error = sendError {
            throw error
        }
    }
}
