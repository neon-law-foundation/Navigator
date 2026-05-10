---
title: "Navigator at a glance"
author: ""
description: "A one-page tour of the Navigator stack — Vapor, Fluent, Postgres, S3, OpenAPI — with comparisons to Rails, Phoenix, and Node."
slug: "navigator-at-a-glance"
---

A one-page tour of what's in this repository.

## What Navigator is

One Swift package with three product surfaces:

1. **A legal-standards library** — `NavigatorRules`, `NavigatorDAL`,
   `NavigatorOIDCMiddleware`, `NavigatorDatabaseService`,
   `NavigatorElementary`, `NavigatorWeb`. Reusable pieces for linting
   markdown notations, modeling people, entities, and notations,
   walking questionnaires, and rendering shared UI.
2. **A public website** — the `NavigatorApp` executable, a Vapor app
   that serves the Foundation site (home, blog, workshops, about,
   contact, privacy, terms).
3. **A CLI** — the `navigator` command for linting, importing, and
   generating notations from templates.

The thesis: **questionnaires + workflows + templates = computable
contracts.**

## The stack

| Concern | Choice |
| --- | --- |
| Language | Swift 6.3 |
| Server | Vapor 4 (with `vapor-elementary` for HTML) |
| HTTP/runtime | SwiftNIO, AsyncHTTPClient |
| ORM | Fluent + FluentKit + SQLKit |
| Database (prod) | PostgreSQL via `fluent-postgres-driver` |
| Database (tests/CLI) | SQLite (in-memory) via `fluent-sqlite-driver` |
| Object storage | AWS S3 via `SotoS3` |
| Email | AWS SES via `SotoSES` |
| API | OpenAPI-first with `swift-openapi-generator`; spec served at `GET /openapi.yaml` |
| Auth | OIDC PKCE, JWT verification (`jwt-kit`), RBAC roles client/staff/admin |
| HTML | `Elementary` — type-safe HTML-as-Swift |
| Markdown | `swift-markdown` |
| Config | `swift-configuration` |
| Crypto | `swift-crypto` |
| Jobs | `vapor/queues` |
| Validation | `NavigatorRules` engine (F101/F102, S101, M001–M060) |
| Tests | Swift Testing |
| Container | Distroless `cc-debian13:nonroot`, static Swift stdlib |

Yes — Vapor and Postgres. Object storage is S3 through Soto. Hummingbird
ships in the graph too, but only as the host for the
`NavigatorElementary` shared-UI module.

## ERD at a glance

The database is grouped into six clusters:

- **Identity** — `Person`, `User` (linked by OIDC `sub`), `UserRoleAudit`.
- **Governance** — `Jurisdiction`, `EntityType`, `Entity`,
  `PersonEntityRole`, `ShareClass`, `ShareIssuance`.
- **Workflow** — `Template`, `Question`, `Answer`, `Notation`, `Project`,
  `PersonProjectRole`, `Retainer`, `RetainerProject`.
- **Documents** — `Blob`, `Document`, `Letter`, `EmailMessage`,
  `EmailAttachment`.
- **Mail and address** — `Mailroom`, `Address` (XOR
  `person_id`/`entity_id`), `Letter`.
- **Billing** — `EntityBillingProfile`, `Invoice`, `InvoiceLineItem`.
- **Provenance** — `GitRepository`, `Disclosure`, `RelationshipLog`.

Every Fluent model carries `id` (UUID), `inserted_at`, `updated_at`.
Validation lives in Swift, not in DB constraints — Fluent best
practice. The full Mermaid diagram is in
`Sources/NavigatorDAL/ERD.md` in the repository.

## Stack comparison

| Concern | Navigator (Swift/Vapor) | Rails | Phoenix | Node (TS) |
| --- | --- | --- | --- | --- |
| Routing (HTML) | Hand-written Vapor `app.get` handlers rendering Elementary views | `routes.rb` + ERB | `router.ex` + HEEx | Express/Fastify + JSX/EJS |
| Routing (JSON API) | OpenAPI-generated handlers (`swift-openapi-generator`) | manual + serializers | manual + JSON views | manual + Zod |
| ORM | Fluent | ActiveRecord | Ecto | Prisma / Drizzle |
| Validation | Swift code + `NavigatorRules` | Model validations | Ecto changesets | Zod / class-validator |
| Templating | `Elementary` (typed) | ERB | HEEx | JSX / EJS |
| Background jobs | `vapor/queues` | Sidekiq / Solid Queue | Oban | BullMQ |
| Concurrency | Actors + structured concurrency | Threads + GVL | BEAM processes | Event loop |
| Type safety | Compile-time, total | Runtime | Compile-time + dialyzer | Compile-time (opt-in) |
| Deploy artifact | Static binary in distroless image | Ruby + bundler image | Mix release | Node + `node_modules` |

## What to look for first

1. `Package.swift` — the module graph is the table of contents.
2. `Sources/NavigatorWeb/openapi.yaml` — the API contract.
3. `Sources/NavigatorDAL/Models/` and
   `Sources/NavigatorDAL/Migrations/` — the domain.
4. `Sources/NavigatorApp/routes.swift` — the website surface.
5. `Sources/NavigatorRules/` — the validation seam other CLIs extend.

That's Navigator on one page.
