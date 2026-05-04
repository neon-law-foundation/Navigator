# NavigatorDAL

Data Access Layer for the Navigator application with Fluent ORM support.

## Features

- **34 Fluent Models** with complete relationships
- **51 Database Migrations** with foreign keys and constraints
- **27 Repositories** with domain-specific queries
- **Environment-based Database Configuration** (ENV variable)

## Database Configuration

The database is automatically configured based on the `ENV` environment
variable, following the same pattern as NLF/Web:

### Environment Variables

#### ENV (Required for environment selection)

- `ENV=production` → Uses PostgreSQL
- `ENV=testing` → Uses SQLite (in-memory)
- `ENV=development` or unset → Uses SQLite (file-based)

#### PostgreSQL Configuration (when ENV=production)

- `DATABASE_HOST` - PostgreSQL host (default: `localhost`)
- `DATABASE_PORT` - PostgreSQL port (default: `5432`)
- `DATABASE_USERNAME` - PostgreSQL username (default: `postgres`)
- `DATABASE_PASSWORD` - PostgreSQL password (default: empty)
- `DATABASE_NAME` - PostgreSQL database name (default: `navigator`)

#### SQLite Configuration (when ENV=development)

- `DATABASE_PATH` - SQLite file path (default: `db/navigator.sqlite`)

## Usage

### Basic Configuration

```swift
import NavigatorDAL
import Vapor

let app = try await Application.make(.detect())

// Automatically configures based on ENV variable
try await NavigatorDALConfiguration.configure(app)

// Now use the database
let personRepo = PersonRepository(database: app.db)
let person = Person()
person.name = "John Doe"
person.email = "john@example.com"
try await personRepo.create(model: person)
```

### Production

```swift
// Set environment variable before running
// ENV=production swift run YourApp

let app = try await Application.make(.detect())

// Will use PostgreSQL based on ENV=production
try await NavigatorDALConfiguration.configure(app)
```

## Models

All models use `UUID` primary keys (generated client-side) and include timestamps:

- **Person** - Individual people with email
- **User** - User accounts with authentication
- **Jurisdiction** - Legal jurisdictions (state, country, etc.)
- **EntityType** - Types of legal entities per jurisdiction
- **Entity** - Legal entities (companies, organizations)
- **ShareClass** - Share classes for entities
- **Credential** - Professional credentials (licenses)
- **Project** - Matter projects
- **Disclosure** - Credential disclosures for projects
- **RelationshipLog** - Project-credential relationship logs
- **Question** - Form questions with various types
- **Address** - Physical addresses (for people or entities)
- **Mailbox** - Mailboxes at addresses
- **PersonEntityRole** - Person roles within entities
- **Blob** - File storage references (polymorphic)
- **EntityBillingProfile** - Links a Navigator entity to a billing provider's
  contact record (e.g. a Xero `ContactID`); one profile per entity per
  provider
- **Invoice** - Mirror of an upstream billing provider's invoice header (Xero
  first); reconciled idempotently via `InvoiceRepository.upsert`
- **InvoiceLineItem** - Child rows of an invoice; reconciled by
  **full replacement** in a single transaction, never per-row merge

## External-System Mirror Tables

Some tables in NavigatorDAL are one-way mirrors of state owned by an upstream
provider — the provider is the system of record, Navigator never originates
those rows. These tables follow a shared timestamp convention:

- `inserted_at` / `updated_at` — Navigator-managed timestamps (Fluent
  `@Timestamp`).
- `external_created_at` / `external_updated_at` — only when the upstream API
  exposes them. Xero's invoice payload exposes only `UpdatedDateUTC`, so
  `Invoice` carries `external_updated_at` but no `external_created_at`.
- `synced_at` — when the sync job last reconciled the row, regardless of
  whether any business field changed. Lets operators distinguish "checked
  recently" from "actually changed recently".

Idempotency uses the upstream identifier as part of a unique key (e.g.
`UNIQUE (billing_profile_id, external_invoice_id)` on `invoices`); the sync
short-circuits when `external_updated_at` has not advanced.

Current mirror tables:

- **invoices** — Xero invoice headers
- **invoice_line_items** — Xero invoice lines, reconciled by full replacement
  (atomic delete-then-reinsert in one transaction, never per-row merge)

## Repositories

Each model has a corresponding repository with CRUD operations plus
domain-specific queries:

```swift
// Example: PersonRepository
let repo = PersonRepository(database: db)

// Basic CRUD
let person = try await repo.find(id: 1)
let all = try await repo.findAll()
try await repo.create(model: newPerson)
try await repo.update(model: existingPerson)
try await repo.delete(id: 1)

// Domain-specific
let person = try await repo.findByEmail("john@example.com")
```

### Repository Methods by Model

- **PersonRepository**: `findByEmail(_:)`
- **UserRepository**: `findBySub(_:)`
- **JurisdictionRepository**: `findByCode(_:)`
- **EntityTypeRepository**: `findByJurisdiction(jurisdictionId:)`
- **EntityRepository**: `findByType(legalEntityTypeId:)`
- **ShareClassRepository**: `findByEntity(entityId:)`
- **BlobRepository**: `findByReference(referencedBy:referencedById:)`
- **ProjectRepository**: `findByCodename(_:)`
- **CredentialRepository**: `findByPerson(personId:)`,
  `findByJurisdiction(jurisdictionId:)`
- **RelationshipLogRepository**: `findByProject(projectId:)`,
  `findByCredential(credentialId:)`
- **DisclosureRepository**: `findActive()`, `findByProject(projectId:)`,
  `findByCredential(credentialId:)`
- **QuestionRepository**: `findByCode(_:)`, `findByType(_:)`
- **AddressRepository**: `findByPerson(personId:)`, `findByEntity(entityId:)`,
  `findVerified()`
- **MailboxRepository**: `findByAddress(addressId:)`, `findActive()`
- **PersonEntityRoleRepository**: `findByPerson(personId:)`,
  `findByEntity(entityId:)`, `findByRole(_:)`

## Migration Order

Migrations run in dependency order:

1. People
2. Users (depends on People)
3. Jurisdictions
4. EntityTypes (depends on Jurisdictions)
5. Entities (depends on EntityTypes)
6. ShareClasses (depends on Entities)
7. Blobs
8. Projects
9. Credentials (depends on People, Jurisdictions)
10. RelationshipLogs (depends on Projects, Credentials)
11. Disclosures (depends on Credentials, Projects)
12. Questions
13. Addresses (depends on Entities, People)
14. Mailboxes (depends on Addresses)
15. PersonEntityRoles (depends on People, Entities)
