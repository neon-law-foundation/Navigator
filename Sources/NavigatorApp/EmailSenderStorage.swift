import NavigatorWeb
import Vapor

/// Lets `configure()` (production) and the test harness (recording stub)
/// each install their own ``EmailSender`` without the admin routes having
/// to know which one is wired.
///
/// Reads default to ``EmailService`` so a production app that never sets
/// the slot still ends up calling SES exactly the way it does today.
struct EmailSenderStorageKey: StorageKey {
    typealias Value = any EmailSender
}

extension Application {
    /// The ``EmailSender`` admin routes use for outbound delivery.
    ///
    /// Tests stash a recording stub here before booting the app; production
    /// runs leave it untouched and pick up ``EmailService`` as the default.
    public var emailSender: any EmailSender {
        get { storage[EmailSenderStorageKey.self] ?? EmailService() }
        set { storage[EmailSenderStorageKey.self] = newValue }
    }
}
