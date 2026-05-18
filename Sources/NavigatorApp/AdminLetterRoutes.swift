import FluentKit
import Foundation
import NavigatorDAL
import NavigatorDatabaseService
import NavigatorWeb
import Vapor
import VaporElementary

/// Add-a-letter form routes for `/admin/mailroom/letters/*`.
///
/// The list view still lives at `/admin/mailroom` (rendered by
/// `MailroomPage`); these routes only handle authoring a new Letter row
/// through the admin chrome.
func registerAdminLetterRoutes(_ app: Application, brand: any Brand) {
    let group = app.grouped("admin", "mailroom", "letters")

    group.get("new") { req -> HTMLResponse in
        let db = try await requireDatabaseService(req).db
        let mailrooms = try await Mailroom.query(on: db).sort(\.$name).all()
        return HTMLResponse {
            AdminLetterFormPage(
                brand: brand,
                mailrooms: mailrooms,
                form: LetterFormValues(),
                errors: .none
            )
        }
    }

    group.post { req -> Response in
        let payload = (try? req.content.decode(LetterPayload.self)) ?? .empty
        let values = payload.values
        let db = try await requireDatabaseService(req).db
        let mailrooms = try await Mailroom.query(on: db).sort(\.$name).all()
        let errors = validateLetter(values: values, mailrooms: mailrooms)
        if !errors.summary.isEmpty {
            let html = HTMLResponse {
                AdminLetterFormPage(
                    brand: brand,
                    mailrooms: mailrooms,
                    form: values,
                    errors: errors
                )
            }
            return try await html.encodeResponse(status: .unprocessableEntity, for: req)
        }
        let letter = Letter()
        apply(values: values, to: letter)
        try await letter.save(on: db)
        return req.redirect(to: "/admin/mailroom", redirectType: .normal)
    }
}

private struct LetterPayload: Content {
    var mailroomId: String?
    var mailboxNumber: String?
    var sender: String?
    var subject: String?
    var receivedAt: String?

    static let empty = LetterPayload(
        mailroomId: nil,
        mailboxNumber: nil,
        sender: nil,
        subject: nil,
        receivedAt: nil
    )

    var values: LetterFormValues {
        LetterFormValues(
            mailroomId: mailroomId ?? "",
            mailboxNumber: mailboxNumber ?? "",
            sender: sender ?? "",
            subject: subject ?? "",
            receivedAt: receivedAt ?? ""
        )
    }
}

private func validateLetter(
    values: LetterFormValues,
    mailrooms: [Mailroom]
) -> LetterFormErrors {
    var summary: [String] = []
    let mailroomError: String?
    if values.mailroomId.isEmpty
        || !mailrooms.contains(where: { $0.id?.uuidString == values.mailroomId })
    {
        mailroomError = "Pick a mailroom."
        summary.append(mailroomError!)
    } else {
        mailroomError = nil
    }
    let mailboxError: String?
    let trimmedMailbox = values.mailboxNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedMailbox.isEmpty && Int(trimmedMailbox) == nil {
        mailboxError = "Mailbox number must be an integer."
        summary.append(mailboxError!)
    } else {
        mailboxError = nil
    }
    let receivedAtError: String?
    let trimmedReceived = values.receivedAt.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedReceived.isEmpty && letterDateFormatter.date(from: trimmedReceived) == nil {
        receivedAtError = "Received date must be YYYY-MM-DD."
        summary.append(receivedAtError!)
    } else {
        receivedAtError = nil
    }
    return LetterFormErrors(
        mailroomId: mailroomError,
        mailboxNumber: mailboxError,
        sender: nil,
        subject: nil,
        receivedAt: receivedAtError,
        summary: summary
    )
}

private func apply(values: LetterFormValues, to letter: Letter) {
    if let id = UUID(uuidString: values.mailroomId) { letter.$mailroom.id = id }
    let trimmedMailbox = values.mailboxNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    letter.mailboxNumber = trimmedMailbox.isEmpty ? nil : Int(trimmedMailbox)
    let trimmedSender = values.sender.trimmingCharacters(in: .whitespacesAndNewlines)
    letter.sender = trimmedSender.isEmpty ? nil : trimmedSender
    let trimmedSubject = values.subject.trimmingCharacters(in: .whitespacesAndNewlines)
    letter.subject = trimmedSubject.isEmpty ? nil : trimmedSubject
    let trimmedReceived = values.receivedAt.trimmingCharacters(in: .whitespacesAndNewlines)
    letter.receivedAt =
        trimmedReceived.isEmpty
        ? nil : letterDateFormatter.date(from: trimmedReceived)
}

/// Parses the `YYYY-MM-DD` value the `<input type="date">` submits. The
/// browser-supplied format is locale-independent, so a fixed POSIX
/// formatter is enough.
private let letterDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "UTC")
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()
