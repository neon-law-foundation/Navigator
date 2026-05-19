import Elementary
import Foundation
import NavigatorDAL
import NavigatorWeb

/// Read-only list of every retainer with its status and clients.
struct RetainersIndexPage: HTML {
    let brand: any Brand
    let retainers: [Retainer]

    var body: some HTML {
        AdminPageLayout(pageTitle: "Retainers", activeSection: .retainers, brand: brand) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(retainers.count) retainer\(retainers.count == 1 ? "" : "s")"
                }
                p(.class("text-xs text-gray-500")) {
                    "Retainers are created by the API when the signing notation reaches its terminal state."
                }
            }
            if retainers.isEmpty {
                AdminEmptyState(
                    message: "No retainers yet.",
                    ctaHref: "/admin/notations",
                    ctaLabel: "View notations"
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Status")
                                AdminTableHeader("Clients")
                                AdminTableHeader("Starts")
                                AdminTableHeader("Ends")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for r in retainers {
                                tr {
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        a(
                                            .href("/admin/retainers/\(r.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { r.status.rawValue }
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        "\(r.clients.value.count) client\(r.clients.value.count == 1 ? "" : "s")"
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        SimpleListFormat.shortDate(r.startsAt)
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        SimpleListFormat.shortDate(r.endsAt)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RetainerShowPage: HTML {
    let brand: any Brand
    let retainer: Retainer

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Retainer",
            activeSection: .retainers,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/retainers"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to retainers"
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Status" }
                    dd(.class("font-mono text-gray-900")) { retainer.status.rawValue }
                    dt(.class("text-gray-500")) { "Starts" }
                    dd(.class("font-mono text-gray-700")) {
                        SimpleListFormat.shortDate(retainer.startsAt)
                    }
                    dt(.class("text-gray-500")) { "Ends" }
                    dd(.class("font-mono text-gray-700")) {
                        SimpleListFormat.shortDate(retainer.endsAt)
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Clients" }
                if retainer.clients.value.isEmpty {
                    p(.class("text-sm text-gray-500")) { "No clients on this retainer." }
                } else {
                    ul(.class("space-y-1 text-sm font-mono")) {
                        for client in retainer.clients.value {
                            li { "\(client.type.rawValue): \(client.id.uuidString)" }
                        }
                    }
                }
            }
        }
    }
}

struct DisclosuresIndexPage: HTML {
    let brand: any Brand
    let disclosures: [Disclosure]

    var body: some HTML {
        AdminPageLayout(pageTitle: "Disclosures", activeSection: .disclosures, brand: brand) {
            p(.class("text-sm text-gray-600 mb-6")) {
                "\(disclosures.count) disclosure\(disclosures.count == 1 ? "" : "s")"
            }
            if disclosures.isEmpty {
                AdminEmptyState(
                    message: "No disclosures yet.",
                    ctaHref: "/admin",
                    ctaLabel: "Back to dashboard"
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Project")
                                AdminTableHeader("Person")
                                AdminTableHeader("Active")
                                AdminTableHeader("Disclosed at")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for d in disclosures {
                                tr(
                                    .custom(name: "data-active", value: d.active ? "true" : "false")
                                ) {
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        d.project.codename
                                    }
                                    td(.class("px-4 py-3 text-sm")) { d.credential.person.name }
                                    td(.class("px-4 py-3 text-sm")) {
                                        d.active ? "active" : "ended"
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        SimpleListFormat.shortDate(d.disclosedAt)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CredentialsIndexPage: HTML {
    let brand: any Brand
    let credentials: [Credential]
    let flash: String?
    let sort: SortSpec
    let filter: String

    static let sortableKeys: Set<String> = ["person", "jurisdiction", "licenseNumber"]
    static let defaultSort: SortSpec = .single("licenseNumber", .ascending)

    static func sorted(_ rows: [Credential], by spec: SortSpec) -> [Credential] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return rows.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "person":
                return a.person.name.localizedCaseInsensitiveCompare(b.person.name)
                    == .orderedAscending
            case "jurisdiction":
                return a.jurisdiction.name.localizedCaseInsensitiveCompare(b.jurisdiction.name)
                    == .orderedAscending
            case "licenseNumber":
                return a.licenseNumber.localizedCaseInsensitiveCompare(b.licenseNumber)
                    == .orderedAscending
            default: return false
            }
        }
    }

    static func filtered(_ rows: [Credential], by query: String) -> [Credential] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return rows }
        return rows.filter {
            $0.licenseNumber.lowercased().contains(trimmed)
                || $0.person.name.lowercased().contains(trimmed)
        }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(pageTitle: "Credentials", activeSection: .credentials, brand: brand) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(credentials.count) credential\(credentials.count == 1 ? "" : "s")"
                }
                LinkButton("New credential", href: "/admin/credentials/new", variant: .primary)
            }
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/credentials",
                value: filter,
                placeholder: "License # or person\u{2026}"
            )
            if credentials.isEmpty {
                AdminEmptyState(
                    message: filter.isEmpty
                        ? "No credentials yet. "
                        : "No credentials matched \u{201C}\(filter)\u{201D}. ",
                    ctaHref: "/admin/credentials/new",
                    ctaLabel: "Add one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminSortableTH(
                                    "Person",
                                    key: "person",
                                    sort: sort,
                                    basePath: "/admin/credentials",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Jurisdiction",
                                    key: "jurisdiction",
                                    sort: sort,
                                    basePath: "/admin/credentials",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "License #",
                                    key: "licenseNumber",
                                    sort: sort,
                                    basePath: "/admin/credentials",
                                    queryItems: queryItems
                                )
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for c in credentials {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) { c.person.name }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) {
                                        c.jurisdiction.name
                                    }
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        c.licenseNumber
                                    }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/credentials/\(c.id?.uuidString ?? "")/edit"),
                                            .class("text-gray-600 hover:text-gray-900")
                                        ) { "Edit" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CredentialFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }
    let brand: any Brand
    let mode: Mode
    let form: CredentialFormValues
    let errors: CredentialFormErrors
    let people: [Person]
    let jurisdictions: [Jurisdiction]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.title,
            activeSection: .credentials,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: mode.action, method: mode.method) {
                    SelectField(
                        name: "personId",
                        label: "Person",
                        options: people.map {
                            SelectOption(value: $0.id?.uuidString ?? "", label: $0.name)
                        },
                        selected: form.personId,
                        required: true,
                        includeBlank: true,
                        blankLabel: "Pick a person\u{2026}",
                        error: errors.personId
                    )
                    SelectField(
                        name: "jurisdictionId",
                        label: "Jurisdiction",
                        options: jurisdictions.map {
                            SelectOption(
                                value: $0.id?.uuidString ?? "",
                                label: "\($0.name) (\($0.code))"
                            )
                        },
                        selected: form.jurisdictionId,
                        required: true,
                        includeBlank: true,
                        blankLabel: "Pick a jurisdiction\u{2026}",
                        error: errors.jurisdictionId
                    )
                    TextField(
                        name: "licenseNumber",
                        label: "License number",
                        value: form.licenseNumber,
                        required: true,
                        error: errors.licenseNumber
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/credentials")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        ConfirmDeleteForm(
                            action: "/admin/credentials/\(id)",
                            label: "Delete credential"
                        )
                    }
                }
            }
        }
    }
}

extension CredentialFormPage.Mode {
    var title: String {
        switch self {
        case .new: "New credential"
        case .edit: "Edit credential"
        }
    }
    var action: String {
        switch self {
        case .new: "/admin/credentials"
        case .edit(let id): "/admin/credentials/\(id)"
        }
    }
    var method: FormMethod {
        switch self {
        case .new: .post
        case .edit: .patch
        }
    }
    var submitLabel: String {
        switch self {
        case .new: "Create credential"
        case .edit: "Save changes"
        }
    }
}

struct CredentialFormValues: Sendable {
    let personId: String
    let jurisdictionId: String
    let licenseNumber: String

    init(personId: String = "", jurisdictionId: String = "", licenseNumber: String = "") {
        self.personId = personId
        self.jurisdictionId = jurisdictionId
        self.licenseNumber = licenseNumber
    }

    init(credential: Credential) {
        self.personId = credential.$person.id.uuidString
        self.jurisdictionId = credential.$jurisdiction.id.uuidString
        self.licenseNumber = credential.licenseNumber
    }
}

struct CredentialFormErrors: Sendable {
    let personId: String?
    let jurisdictionId: String?
    let licenseNumber: String?
    let summary: [String]

    init(
        personId: String? = nil,
        jurisdictionId: String? = nil,
        licenseNumber: String? = nil,
        summary: [String] = []
    ) {
        self.personId = personId
        self.jurisdictionId = jurisdictionId
        self.licenseNumber = licenseNumber
        self.summary = summary
    }

    static let none = CredentialFormErrors()
}

struct InvoicesIndexPage: HTML {
    let brand: any Brand
    let invoices: [Invoice]

    var body: some HTML {
        AdminPageLayout(pageTitle: "Invoices", activeSection: .invoices, brand: brand) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(invoices.count) invoice\(invoices.count == 1 ? "" : "s")"
                }
                p(.class("text-xs text-gray-500")) {
                    "Invoices mirror an upstream billing provider (Xero) and are read-only here."
                }
            }
            if invoices.isEmpty {
                AdminEmptyState(
                    message: "No invoices yet.",
                    ctaHref: "/admin",
                    ctaLabel: "Back to dashboard"
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Number")
                                AdminTableHeader("Status")
                                AdminTableHeader("Type")
                                AdminTableHeader("Total")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for inv in invoices {
                                tr {
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        a(
                                            .href("/admin/invoices/\(inv.id?.uuidString ?? "")"),
                                            .class("text-indigo-700 hover:underline")
                                        ) { inv.invoiceNumber ?? "(draft)" }
                                    }
                                    td(.class("px-4 py-3 text-sm")) { inv.status.rawValue }
                                    td(.class("px-4 py-3 text-sm")) { inv.invoiceType.rawValue }
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        "\(inv.currencyCode) \(NSDecimalNumber(decimal: inv.total).stringValue)"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct InvoiceShowPage: HTML {
    let brand: any Brand
    let invoice: Invoice
    let lineItems: [InvoiceLineItem]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: invoice.invoiceNumber ?? "(draft)",
            activeSection: .invoices,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                a(.href("/admin/invoices"), .class("text-sm text-gray-600 hover:underline")) {
                    "\u{2190} Back to invoices"
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6 mb-6")) {
                dl(.class("grid grid-cols-2 gap-y-3 text-sm")) {
                    dt(.class("text-gray-500")) { "Number" }
                    dd(.class("font-mono text-gray-900")) {
                        invoice.invoiceNumber ?? "(draft)"
                    }
                    dt(.class("text-gray-500")) { "Status" }
                    dd(.class("text-gray-900")) { invoice.status.rawValue }
                    dt(.class("text-gray-500")) { "Total" }
                    dd(.class("font-mono text-gray-900")) {
                        "\(invoice.currencyCode) \(NSDecimalNumber(decimal: invoice.total).stringValue)"
                    }
                    dt(.class("text-gray-500")) { "Amount due" }
                    dd(.class("font-mono text-gray-900")) {
                        NSDecimalNumber(decimal: invoice.amountDue).stringValue
                    }
                }
            }
            section(.class("bg-white rounded-lg border border-gray-200 p-6")) {
                h2(.class("text-lg font-semibold text-gray-900 mb-4")) { "Line items" }
                if lineItems.isEmpty {
                    p(.class("text-sm text-gray-500")) { "No line items." }
                } else {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("#")
                                AdminTableHeader("Description")
                                AdminTableHeader("Quantity")
                                AdminTableHeader("Amount")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for line in lineItems {
                                tr {
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        String(line.lineNumber)
                                    }
                                    td(.class("px-4 py-3 text-sm")) { line.description }
                                    td(.class("px-4 py-3 text-sm text-right font-mono")) {
                                        NSDecimalNumber(decimal: line.quantity).stringValue
                                    }
                                    td(.class("px-4 py-3 text-sm text-right font-mono")) {
                                        NSDecimalNumber(decimal: line.lineAmount).stringValue
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BillingProfilesIndexPage: HTML {
    let brand: any Brand
    let profiles: [EntityBillingProfile]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Billing profiles",
            activeSection: .billingProfiles,
            brand: brand
        ) {
            p(.class("text-sm text-gray-600 mb-6")) {
                "\(profiles.count) profile\(profiles.count == 1 ? "" : "s")"
            }
            if profiles.isEmpty {
                AdminEmptyState(
                    message: "No billing profiles yet.",
                    ctaHref: "/admin/entities",
                    ctaLabel: "Pick an entity to link"
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Entity")
                                AdminTableHeader("Provider")
                                AdminTableHeader("External contact ID")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for p in profiles {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) { p.entity.name }
                                    td(.class("px-4 py-3 text-sm")) { p.provider.rawValue }
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        p.externalContactId
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MailroomsIndexPage: HTML {
    let brand: any Brand
    let mailrooms: [Mailroom]
    let flash: String?
    let sort: SortSpec
    let filter: String

    static let sortableKeys: Set<String> = ["name", "mailboxStart"]
    static let defaultSort: SortSpec = .single("name", .ascending)

    static func sorted(_ rows: [Mailroom], by spec: SortSpec) -> [Mailroom] {
        let primary = spec.fields.first ?? defaultSort.fields.first!
        return rows.sorted { lhs, rhs in
            let (a, b) = primary.direction == .ascending ? (lhs, rhs) : (rhs, lhs)
            switch primary.key {
            case "name":
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case "mailboxStart":
                return a.mailboxStart < b.mailboxStart
            default: return false
            }
        }
    }

    static func filtered(_ rows: [Mailroom], by query: String) -> [Mailroom] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return rows }
        return rows.filter { $0.name.lowercased().contains(trimmed) }
    }

    private var queryItems: [(String, String)] {
        filter.isEmpty ? [] : [("q", filter)]
    }

    var body: some HTML {
        AdminPageLayout(pageTitle: "Mailrooms", activeSection: .mailrooms, brand: brand) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(mailrooms.count) mailroom\(mailrooms.count == 1 ? "" : "s")"
                }
                LinkButton("New mailroom", href: "/admin/mailrooms/new", variant: .primary)
            }
            AdminFlashBanner(message: flash)
            AdminFilterBar(
                action: "/admin/mailrooms",
                value: filter,
                placeholder: "Name\u{2026}"
            )
            if mailrooms.isEmpty {
                AdminEmptyState(
                    message: filter.isEmpty
                        ? "No mailrooms yet. "
                        : "No mailrooms matched \u{201C}\(filter)\u{201D}. ",
                    ctaHref: "/admin/mailrooms/new",
                    ctaLabel: "Add one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminSortableTH(
                                    "Name",
                                    key: "name",
                                    sort: sort,
                                    basePath: "/admin/mailrooms",
                                    queryItems: queryItems
                                )
                                AdminSortableTH(
                                    "Mailbox range",
                                    key: "mailboxStart",
                                    sort: sort,
                                    basePath: "/admin/mailrooms",
                                    queryItems: queryItems
                                )
                                AdminTableHeader("Capacity")
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for m in mailrooms {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) { m.name }
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        "\(m.mailboxStart)–\(m.mailboxEnd)"
                                    }
                                    td(.class("px-4 py-3 text-sm")) {
                                        m.capacity.map(String.init) ?? "\u{2014}"
                                    }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/mailrooms/\(m.id?.uuidString ?? "")/edit"),
                                            .class("text-gray-600 hover:text-gray-900")
                                        ) { "Edit" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MailroomFormPage: HTML {
    enum Mode: Sendable {
        case new
        case edit(id: String)
    }
    let brand: any Brand
    let mode: Mode
    let form: MailroomFormValues
    let errors: MailroomFormErrors

    var body: some HTML {
        AdminPageLayout(
            pageTitle: mode.title,
            activeSection: .mailrooms,
            brand: brand
        ) {
            div(.class("max-w-2xl bg-white p-6 rounded-lg border border-gray-200")) {
                FormErrors(errors.summary)
                FormLayout(action: mode.action, method: mode.method) {
                    TextField(
                        name: "name",
                        label: "Name",
                        value: form.name,
                        required: true,
                        error: errors.name
                    )
                    TextField(
                        name: "mailboxStart",
                        label: "Mailbox start",
                        value: form.mailboxStart,
                        required: true,
                        error: errors.mailboxStart
                    )
                    TextField(
                        name: "mailboxEnd",
                        label: "Mailbox end",
                        value: form.mailboxEnd,
                        required: true,
                        error: errors.mailboxEnd
                    )
                    TextField(
                        name: "capacity",
                        label: "Capacity (optional)",
                        value: form.capacity,
                        error: errors.capacity
                    )
                    div(.class("flex items-center gap-3 mt-6")) {
                        SubmitButton(mode.submitLabel, variant: .primary)
                        LinkButton("Cancel", href: "/admin/mailrooms")
                    }
                }
                if case .edit(let id) = mode {
                    div(.class("mt-8 pt-6 border-t border-gray-200")) {
                        ConfirmDeleteForm(
                            action: "/admin/mailrooms/\(id)",
                            label: "Delete mailroom"
                        )
                    }
                }
            }
        }
    }
}

extension MailroomFormPage.Mode {
    var title: String {
        switch self {
        case .new: "New mailroom"
        case .edit: "Edit mailroom"
        }
    }
    var action: String {
        switch self {
        case .new: "/admin/mailrooms"
        case .edit(let id): "/admin/mailrooms/\(id)"
        }
    }
    var method: FormMethod {
        switch self {
        case .new: .post
        case .edit: .patch
        }
    }
    var submitLabel: String {
        switch self {
        case .new: "Create mailroom"
        case .edit: "Save changes"
        }
    }
}

struct MailroomFormValues: Sendable {
    let name: String
    let mailboxStart: String
    let mailboxEnd: String
    let capacity: String

    init(
        name: String = "",
        mailboxStart: String = "",
        mailboxEnd: String = "",
        capacity: String = ""
    ) {
        self.name = name
        self.mailboxStart = mailboxStart
        self.mailboxEnd = mailboxEnd
        self.capacity = capacity
    }

    init(mailroom: Mailroom) {
        self.name = mailroom.name
        self.mailboxStart = String(mailroom.mailboxStart)
        self.mailboxEnd = String(mailroom.mailboxEnd)
        self.capacity = mailroom.capacity.map(String.init) ?? ""
    }
}

struct MailroomFormErrors: Sendable {
    let name: String?
    let mailboxStart: String?
    let mailboxEnd: String?
    let capacity: String?
    let summary: [String]

    init(
        name: String? = nil,
        mailboxStart: String? = nil,
        mailboxEnd: String? = nil,
        capacity: String? = nil,
        summary: [String] = []
    ) {
        self.name = name
        self.mailboxStart = mailboxStart
        self.mailboxEnd = mailboxEnd
        self.capacity = capacity
        self.summary = summary
    }

    static let none = MailroomFormErrors()
}

struct UsersIndexPage: HTML {
    let brand: any Brand
    let users: [User]

    var body: some HTML {
        AdminPageLayout(pageTitle: "Users", activeSection: .users, brand: brand) {
            p(.class("text-sm text-gray-600 mb-6")) {
                "\(users.count) user\(users.count == 1 ? "" : "s")"
            }
            if users.isEmpty {
                AdminEmptyState(
                    message: "No users yet.",
                    ctaHref: "/admin",
                    ctaLabel: "Back to dashboard"
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Person")
                                AdminTableHeader("Role")
                                AdminTableHeader("Sub")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for u in users {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) { u.person.name }
                                    td(.class("px-4 py-3 text-sm font-mono")) { u.role.rawValue }
                                    td(.class("px-4 py-3 text-xs font-mono text-gray-500")) {
                                        u.sub ?? "\u{2014}"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct UserRoleAuditIndexPage: HTML {
    let brand: any Brand
    let audits: [UserRoleAudit]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "User role audit",
            activeSection: .userRoleAudit,
            brand: brand
        ) {
            p(.class("text-sm text-gray-600 mb-6")) {
                "\(audits.count) audit entr\(audits.count == 1 ? "y" : "ies")"
            }
            if audits.isEmpty {
                AdminEmptyState(
                    message: "No role changes recorded.",
                    ctaHref: "/admin",
                    ctaLabel: "Back to dashboard"
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("When")
                                AdminTableHeader("Subject")
                                AdminTableHeader("Change")
                                AdminTableHeader("Reason")
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for a in audits {
                                tr {
                                    td(.class("px-4 py-3 text-sm font-mono text-gray-500")) {
                                        SimpleListFormat.shortDate(a.insertedAt)
                                    }
                                    td(.class("px-4 py-3 text-sm")) { a.user.person.name }
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        "\(a.previousRole.rawValue) \u{2192} \(a.newRole.rawValue)"
                                    }
                                    td(.class("px-4 py-3 text-sm text-gray-700")) { a.reason }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ShareClassesIndexPage: HTML {
    let brand: any Brand
    let classes: [ShareClass]

    var body: some HTML {
        AdminPageLayout(pageTitle: "Share classes", activeSection: .shareClasses, brand: brand) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(classes.count) share class\(classes.count == 1 ? "" : "es")"
                }
                LinkButton(
                    "New share class",
                    href: "/admin/share-classes/new",
                    variant: .primary
                )
            }
            if classes.isEmpty {
                AdminEmptyState(
                    message: "No share classes yet. ",
                    ctaHref: "/admin/share-classes/new",
                    ctaLabel: "Create one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Entity")
                                AdminTableHeader("Name")
                                AdminTableHeader("Priority", alignment: .right)
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for c in classes {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) { c.entity.name }
                                    td(.class("px-4 py-3 text-sm")) { c.name }
                                    td(.class("px-4 py-3 text-sm text-right font-mono")) {
                                        String(c.priority)
                                    }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/share-classes/\(c.id?.uuidString ?? "")/edit"),
                                            .class("text-gray-600 hover:text-gray-900")
                                        ) { "Edit" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ShareIssuancesIndexPage: HTML {
    let brand: any Brand
    let issuances: [ShareIssuance]

    var body: some HTML {
        AdminPageLayout(
            pageTitle: "Share issuances",
            activeSection: .shareIssuances,
            brand: brand
        ) {
            div(.class("flex items-center justify-between mb-6")) {
                p(.class("text-sm text-gray-600")) {
                    "\(issuances.count) issuance\(issuances.count == 1 ? "" : "s")"
                }
                LinkButton(
                    "New issuance",
                    href: "/admin/share-issuances/new",
                    variant: .primary
                )
            }
            if issuances.isEmpty {
                AdminEmptyState(
                    message: "No issuances yet. ",
                    ctaHref: "/admin/share-issuances/new",
                    ctaLabel: "Record one."
                )
            } else {
                div(.class("overflow-hidden rounded-lg border border-gray-200 bg-white")) {
                    table(.class("min-w-full divide-y divide-gray-200")) {
                        thead(.class("bg-gray-50")) {
                            tr {
                                AdminTableHeader("Entity")
                                AdminTableHeader("Shareholder type")
                                AdminTableHeader("Shareholder ID")
                                AdminTableHeader("", alignment: .right)
                            }
                        }
                        tbody(.class("divide-y divide-gray-100")) {
                            for i in issuances {
                                tr {
                                    td(.class("px-4 py-3 text-sm")) { i.entity.name }
                                    td(.class("px-4 py-3 text-sm font-mono")) {
                                        i.shareholderType.rawValue
                                    }
                                    td(.class("px-4 py-3 text-xs font-mono text-gray-500")) {
                                        i.shareholderId.uuidString
                                    }
                                    td(.class("px-4 py-3 text-sm text-right")) {
                                        a(
                                            .href("/admin/share-issuances/\(i.id?.uuidString ?? "")/edit"),
                                            .class("text-gray-600 hover:text-gray-900")
                                        ) { "Edit" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Shared formatting helpers for the simple list pages. Pulled into a
/// single enum so the small calendar-only date formatter is cached and
/// the page bodies stay declarative.
enum SimpleListFormat {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func shortDate(_ date: Date?) -> String {
        guard let date else { return "\u{2014}" }
        return dateFormatter.string(from: date)
    }
}
