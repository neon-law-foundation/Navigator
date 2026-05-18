import Elementary
import NavigatorWeb

/// Placeholder for the outbound `/admin/messages` surface.
///
/// Sending mail from the admin requires loosening the `EmailMessage`
/// schema (the SES verdict columns are not meaningful for outbound rows)
/// and wiring through `EmailService` — both are out of scope for this PR.
/// The page exists so the sidebar link does not 404 and to make the
/// follow-up work discoverable.
struct AdminMessagesPlaceholderPage: HTML {
    let brand: any Brand

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Messages",
            activeSection: .messages,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white rounded-lg border border-gray-200 p-6")) {
                p(.class("text-gray-600 mb-3")) {
                    "Outbound messaging is not wired up yet."
                }
                p(.class("text-sm text-gray-500")) {
                    "It will compose a new EmailMessage row marked outbound and dispatch via EmailService. This requires the EmailMessage SES-verdict columns to become optional first; tracking as follow-up."
                }
            }
        }
    }
}
