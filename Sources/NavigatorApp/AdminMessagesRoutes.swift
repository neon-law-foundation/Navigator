import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Routes for `/admin/messages/*` — outbound mail compose, send, list.
///
/// Outbound rows share the `EmailMessage` schema with inbound rows; this
/// surface filters to `direction == .outbound` so the inbox stays focused
/// on received mail.
///
/// Sending is wired through ``Application/emailSender`` so tests can
/// inject a recording stub instead of touching SES. Send failures do not
/// roll back the persisted row — the row is the audit record of what an
/// operator intended to send; the show page surfaces the send error as
/// an amber banner so the operator can retry out-of-band.
func registerAdminMessagesRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "messages")

    group.get { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let all = try await EmailMessage.query(on: db)
            .sort(\.$receivedAt, .descending)
            .all()
        let outbound = all.filter { $0.direction == .outbound }
        let flash = (try? req.query.get(String.self, at: "flash")).map { decodeFlash($0) }
        return HTMLResponse {
            MessagesIndexPage(brand: brand, messages: outbound, flash: flash)
        }
    }

    group.get("new") { req -> HTMLResponse in
        // Pre-fill from `?reply_to=<inbound-message-id>` so the Reply
        // button on the inbox detail page lands the operator on a form
        // that is already threaded back into the parent conversation.
        let replyToParam = try? req.query.get(String.self, at: "reply_to")
        var form = MessageFormValues()
        var replyContext: MessageReplyContext? = nil
        if let replyToParam, let replyToID = UUID(uuidString: replyToParam) {
            let db = try await requireDatabaseService(req).db
            if let parent = try await EmailMessage.find(replyToID, on: db) {
                let replySubject =
                    parent.subject.lowercased().hasPrefix("re:")
                    ? parent.subject : "Re: \(parent.subject)"
                form = MessageFormValues(
                    to: parent.fromAddress,
                    subject: replySubject,
                    body: ""
                )
                replyContext = MessageReplyContext(
                    inReplyTo: parent.messageId,
                    parentThreadId: parent.threadId,
                    originalSubject: parent.subject
                )
            }
        }
        return HTMLResponse {
            MessageComposePage(
                brand: brand,
                form: form,
                errors: .none,
                replyContext: replyContext
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(MessagePayload.self)) ?? .empty
        let values = payload.values
        let errors = validateMessage(values: values)
        if !errors.summary.isEmpty {
            let replyContext = payload.replyContext
            let html = HTMLResponse {
                MessageComposePage(
                    brand: brand,
                    form: values,
                    errors: errors,
                    replyContext: replyContext
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let db = try await requireDatabaseService(req).db
        let fromAddress = EmailMessage.supportFromAddresses.first ?? "support@neonlaw.org"
        let saved = try await EmailMessageRepository(database: db).createOutbound(
            to: values.to.trimmingCharacters(in: .whitespacesAndNewlines),
            from: fromAddress,
            subject: values.subject.trimmingCharacters(in: .whitespacesAndNewlines),
            textBody: values.body,
            inReplyTo: payload.inReplyTo?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            parentThreadId: payload.parentThreadId?.trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
        )
        let outbound = OutboundEmail(
            to: saved.toAddress,
            from: saved.fromAddress,
            subject: saved.subject,
            body: saved.textBody ?? ""
        )
        var sendError: String? = nil
        do {
            try await req.application.emailSender.send(outbound)
        } catch {
            // Persisted row stays — show page surfaces the failure so the
            // operator can decide whether to retry or follow up manually.
            sendError = "\(error)"
        }
        let flash: String
        if let sendError {
            flash = encodeFlash(
                "Saved but send failed: \(sendError). See the message detail page for details."
            )
        } else {
            flash = encodeFlash("Message sent to \(saved.toAddress).")
        }
        return req.redirect(
            to: "/admin/messages/\(saved.id!.uuidString)?flash=\(flash)"
                + (sendError == nil ? "" : "&send_error=\(encodeFlash(sendError!))"),
            redirectType: .normal
        )
    }

    group.get(":id") { req -> HTMLResponse in
        guard let raw = req.parameters.get("id"), let id = UUID(uuidString: raw) else {
            throw Abort(.badRequest, reason: "Invalid message id.")
        }
        let db = try await requireDatabaseService(req).db
        guard let message = try await EmailMessage.find(id, on: db) else {
            throw Abort(.notFound)
        }
        let sendError = (try? req.query.get(String.self, at: "send_error")).map { decodeFlash($0) }
        return HTMLResponse {
            MessageShowPage(brand: brand, message: message, sendError: sendError)
        }
    }
}

private struct MessagePayload: Content {
    var to: String?
    var subject: String?
    var body: String?
    var inReplyTo: String?
    var parentThreadId: String?

    static let empty = MessagePayload(
        to: nil,
        subject: nil,
        body: nil,
        inReplyTo: nil,
        parentThreadId: nil
    )

    var values: MessageFormValues {
        MessageFormValues(to: to ?? "", subject: subject ?? "", body: body ?? "")
    }

    /// Echoed back into the form on a validation failure so the hidden
    /// reply fields survive the round-trip.
    var replyContext: MessageReplyContext? {
        guard let inReplyTo = inReplyTo?.nonEmpty,
            let parentThreadId = parentThreadId?.nonEmpty
        else { return nil }
        return MessageReplyContext(
            inReplyTo: inReplyTo,
            parentThreadId: parentThreadId,
            originalSubject: ""
        )
    }
}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}

private func validateMessage(values: MessageFormValues) -> MessageFormErrors {
    var summary: [String] = []
    let trimmedTo = values.to.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedSubject = values.subject.trimmingCharacters(in: .whitespacesAndNewlines)
    let toError: String?
    if trimmedTo.isEmpty {
        toError = "Recipient is required."
        summary.append(toError!)
    } else if !trimmedTo.contains("@") {
        toError = "Recipient must look like an email address."
        summary.append(toError!)
    } else {
        toError = nil
    }
    let subjectError: String?
    if trimmedSubject.isEmpty {
        subjectError = "Subject is required."
        summary.append(subjectError!)
    } else {
        subjectError = nil
    }
    let bodyError: String?
    if values.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        bodyError = "Body is required."
        summary.append(bodyError!)
    } else {
        bodyError = nil
    }
    return MessageFormErrors(
        to: toError,
        subject: subjectError,
        body: bodyError,
        summary: summary
    )
}
