# Navigator

The Neon Law Foundation's public, open-source legal-standards library and
website. Hosted as a public repository.

## Open-Source Isolation — CRITICAL

This repository is fully open source. **It must never reference any other
repository or organization, public or private.** Treat every file in this
tree — code, comments, docs, commit messages, PR titles, PR descriptions,
issue bodies, branch names — as world-readable.

**Forbidden** in any artifact that lives in or about this repository:

- Names of other organizations, sibling repositories, or private repos
- Internal account identifiers, infrastructure account names, deployment
  topology shared with other workloads, or anything implying coordination
  with another codebase
- Cross-repo issue/PR links, "this is part of <X>", "see also <Y>",
  "downstream of <Z>" framing

If a change here was motivated by a need elsewhere, describe the change
on its own merits — what it does for **this** project, in this project's
language. Do not narrate the cross-repo motivation.

Treat any leak of the above as a confidentiality incident.

## Stack

Pure-Swift legal-standards library plus a Vapor-served public website.
See `Package.swift` for the module graph and `README.md` for the
quick-start.

## Data Layer — Fluent only, no raw SQL

All database access goes through Fluent. **Do not write raw SQL** — no
`sql.raw(...)` calls, no `SQLDatabase` dialect branches, no engine-specific
features (Postgres `@>` / GIN / partial indexes, SQLite `PRAGMA` /
`sqlite_master`). Migrations use Fluent's portable schema builder; queries
use Fluent's query builder; JSON-typed columns use the `JSONStored<T>`
wrapper so encoding is identical on SQLite and Postgres. If a feature can
only be expressed in engine-specific SQL, drop the feature rather than
adding the SQL — the code path must look the same regardless of which
backend is configured.

### JSONB queries

Fluent's portable query builder is sufficient for every current read path.
JSONB-specific operators (`@>`, GIN, `jsonb_path_*`) and any raw SQL
helpers stay deferred until a concrete read path requires more than
O(N) Swift-side filtering on a JSONB column. Today, `RetainerRepository`
and `Notation.hasActiveAssignment` pull rows with Fluent and filter in
Swift — this is acceptable for the row counts we host. Re-open the
discussion before introducing the first JSONB operator.

## Targets

- **Library** modules expose the legal standards, rules, data layer, and
  shared web UI for public consumption.
- **`NavigatorApp`** executable serves the public Neon Law Foundation
  website.
- **`NavigatorCLI`** executable provides the agent/dev tooling shipped
  with the library.
