import Foundation
import Testing

@testable import NavigatorDAL

@Suite("EmailMessage direction inference")
struct EmailMessageDirectionTests {

    @Test("from_address matching a support mailbox reads as outbound")
    func outboundWhenSenderIsSupportMailbox() {
        let m = EmailMessage()
        m.fromAddress = "support@neonlaw.org"
        m.toAddress = "client@example.com"
        m.subject = "Sent"
        m.threadId = "x"
        m.messageId = "x"
        m.spamVerdict = "NOT_APPLICABLE"
        m.virusVerdict = "NOT_APPLICABLE"
        m.dkimVerdict = "NOT_APPLICABLE"
        m.dmarcVerdict = "NOT_APPLICABLE"
        m.receivedAt = Date()
        #expect(m.direction == .outbound)
    }

    @Test("from_address that is not a support mailbox reads as inbound")
    func inboundForExternalSender() {
        let m = EmailMessage()
        m.fromAddress = "client@example.com"
        m.toAddress = "support@neonlaw.org"
        m.subject = "Received"
        m.threadId = "x"
        m.messageId = "x"
        m.spamVerdict = "PASS"
        m.virusVerdict = "PASS"
        m.dkimVerdict = "PASS"
        m.dmarcVerdict = "PASS"
        m.receivedAt = Date()
        #expect(m.direction == .inbound)
    }

    @Test("direction inference is case-insensitive on the from address")
    func caseInsensitiveSenderMatch() {
        let m = EmailMessage()
        m.fromAddress = "Support@NeonLaw.Org"
        m.toAddress = "client@example.com"
        m.subject = "Sent"
        m.threadId = "x"
        m.messageId = "x"
        m.spamVerdict = "NOT_APPLICABLE"
        m.virusVerdict = "NOT_APPLICABLE"
        m.dkimVerdict = "NOT_APPLICABLE"
        m.dmarcVerdict = "NOT_APPLICABLE"
        m.receivedAt = Date()
        #expect(m.direction == .outbound)
    }
}
