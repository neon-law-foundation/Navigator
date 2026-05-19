import Foundation

/// A section in the admin sidebar.
///
/// The case order in this enum is the order the sidebar renders. The
/// `href` is the canonical landing page for the section — every list
/// page in the section starts there. `label` is the visible nav-link
/// text.
enum AdminSection: String, CaseIterable, Sendable {
    case dashboard
    case search
    case projects
    case people
    case entities
    case entityTypes
    case contacts
    case messages
    case inbox
    case mailroom
    case notations
    case templates
    case questions
    case retainers
    case disclosures
    case credentials
    case invoices
    case billingProfiles
    case jurisdictions
    case mailrooms
    case users
    case userRoleAudit
    case shareClasses
    case shareIssuances

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .search: "Search"
        case .projects: "Projects"
        case .people: "People"
        case .entities: "Entities"
        case .entityTypes: "Entity types"
        case .contacts: "Contacts"
        case .messages: "Messages"
        case .inbox: "Inbox"
        case .mailroom: "Mail room"
        case .notations: "Notations"
        case .templates: "Templates"
        case .questions: "Questions"
        case .retainers: "Retainers"
        case .disclosures: "Disclosures"
        case .credentials: "Credentials"
        case .invoices: "Invoices"
        case .billingProfiles: "Billing profiles"
        case .jurisdictions: "Jurisdictions"
        case .mailrooms: "Mailrooms"
        case .users: "Users"
        case .userRoleAudit: "User role audit"
        case .shareClasses: "Share classes"
        case .shareIssuances: "Share issuances"
        }
    }

    var href: String {
        switch self {
        case .dashboard: "/admin"
        case .search: "/admin/search"
        case .projects: "/admin/projects"
        case .people: "/admin/people"
        case .entities: "/admin/entities"
        case .entityTypes: "/admin/entity-types"
        case .contacts: "/admin/contacts"
        case .messages: "/admin/messages"
        case .inbox: "/admin/inbox"
        case .mailroom: "/admin/mailroom"
        case .notations: "/admin/notations"
        case .templates: "/admin/templates"
        case .questions: "/admin/questions"
        case .retainers: "/admin/retainers"
        case .disclosures: "/admin/disclosures"
        case .credentials: "/admin/credentials"
        case .invoices: "/admin/invoices"
        case .billingProfiles: "/admin/billing-profiles"
        case .jurisdictions: "/admin/jurisdictions"
        case .mailrooms: "/admin/mailrooms"
        case .users: "/admin/users"
        case .userRoleAudit: "/admin/user-role-audit"
        case .shareClasses: "/admin/share-classes"
        case .shareIssuances: "/admin/share-issuances"
        }
    }

    /// Visual grouping rendered as a section heading in the sidebar.
    /// Keeps the 23 sections from collapsing into one wall of links.
    var group: AdminSidebarGroup {
        switch self {
        case .dashboard, .search:
            .overview
        case .projects, .people, .entities, .entityTypes, .contacts:
            .directory
        case .messages, .inbox, .mailroom:
            .correspondence
        case .notations, .templates, .questions:
            .workflow
        case .retainers, .disclosures, .credentials:
            .access
        case .invoices, .billingProfiles:
            .billing
        case .jurisdictions, .mailrooms, .users, .userRoleAudit:
            .reference
        case .shareClasses, .shareIssuances:
            .capTable
        }
    }
}

/// Headings the sidebar uses to group sections.
enum AdminSidebarGroup: String, CaseIterable, Sendable {
    case overview
    case directory
    case correspondence
    case workflow
    case access
    case billing
    case reference
    case capTable

    var label: String {
        switch self {
        case .overview: "Overview"
        case .directory: "Directory"
        case .correspondence: "Correspondence"
        case .workflow: "Workflow"
        case .access: "Access"
        case .billing: "Billing"
        case .reference: "Reference data"
        case .capTable: "Cap table"
        }
    }
}
