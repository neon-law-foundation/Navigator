# Navigator

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)

Questionnaires, Workflows, and Templates together to create computable
contracts.

## What lives here

This repository ships two things side by side:

1. **The Navigator template library and CLI** — Swift packages
   (`NavigatorRules`, `NavigatorDAL`, `NavigatorOIDCMiddleware`,
   `NavigatorDatabaseService`, `NavigatorElementary`, `NavigatorWeb`)
   plus the `navigator` command-line tool. These are the reusable
   pieces other projects depend on to lint markdown notations, seed
   databases, walk questionnaires, and render shared UI.
2. **The `neonlaw.org` website** — the `NavigatorApp` executable target
   at `Sources/NavigatorApp/`, which serves the public Neon Law
   Foundation site (home, blog, workshops, about, contact, privacy,
   terms). It is a Vapor app that renders every page through
   `NavigatorWeb` components and is packaged as a container image for
   deployment.

The two share one Swift package and one test suite so a component
edit lands with the page that consumes it in a single commit.

## Overview

Navigator is a base setup for delivering legal services with full-stack Swift. It runs as a
CLI for adding and updating documents locally, or as a web service. Questionnaires and
workflows defined alongside the documents provide the hooks for plugging in automations.

## Installation

### macOS — Homebrew (recommended)

```bash
brew tap neon-law-foundation/tap
brew install navigator
```

The formula in
[neon-law-foundation/homebrew-tap](https://github.com/neon-law-foundation/homebrew-tap)
is updated weekly at Sunday 02:00 UTC by `.github/workflows/weekly-release.yaml`,
which publishes a versioned macOS release for Apple Silicon and Intel and rewrites
`Formula/navigator.rb` with the new tarball URLs and SHAs.

Upgrade later with:

```bash
brew update && brew upgrade navigator
```

### Linux — build from source

No Homebrew formula is published for Linux. Build the `NavigatorCLI` product
directly with Swift 6.3 or newer. The instructions below have been verified on
Ubuntu, Fedora, and Arch; any distro with a Swift 6.3+ toolchain will work.

#### 1. Install Swift 6.3+

[`swiftly`](https://swiftlang.github.io/swiftly/) is the easiest path and
manages multiple toolchains side by side:

```bash
curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
. ~/.local/share/swiftly/env.sh
swiftly install 6.3
```

If your package manager ships Swift 6.3+ you can use that instead — for
example, `sudo pacman -S swift` on Arch.

#### 2. Install system dependencies

Ubuntu / Debian:

```bash
sudo apt-get install -y build-essential libcurl4-openssl-dev \
  libsqlite3-dev libxml2-dev
```

Fedora / RHEL:

```bash
sudo dnf install -y gcc libcurl-devel sqlite-devel libxml2-devel
```

Arch:

```bash
sudo pacman -S --needed base-devel curl sqlite libxml2
```

#### 3. Build and install

```bash
git clone https://github.com/neon-law-foundation/Navigator.git
cd Navigator
swift build -c release --product NavigatorCLI
install -Dm755 .build/release/NavigatorCLI ~/.local/bin/navigator
```

Make sure `~/.local/bin` is on your `PATH`, then verify the install:

```bash
navigator --version
navigator --help
```

To rebuild after pulling updates, repeat step 3 from inside the cloned
directory.

## Commands

### `navigator lint <directory>`

Validates Markdown files. **Does not persist to database.**

```bash
navigator lint .
navigator lint ShookFamily/Estate
```

**Rules:**

- **S101**: Line length ≤120 characters
- **F101**: Non-empty `title` in frontmatter
- **F102**: Valid `respondent_type`: `entity`, `person`, or `person_and_entity`

README.md and CLAUDE.md files are excluded.

### `navigator import <directory>`

Validates and imports markdown files to in-memory SQLite database. Auto-detects git
repository and commit SHA.

```bash
navigator import .
navigator import ./notations
```

**Requirements:**

- Git repository with remote origin
- Clean working tree (no uncommitted changes)
- Files pass F101, F102 validation

**Auto-Detection:**

- Repository ID: Hashed from `git remote get-url origin`
- Commit SHA: `git rev-parse HEAD`

**Example:**

```text
Git Repository ID: 1234567890
Git Commit SHA: a1b2c3d4...
All files valid. Starting import...
Imported: contractor-agreement.md
Imported: nda.md
Successfully imported: 2 notation(s)
```

**Errors:**

- Not a git repository
- Uncommitted changes detected
- No remote origin configured
- Validation failures

### `navigator notation <template>`

Creates a notation interactively by walking a template's questionnaire. Accepts
either a seeded template code or a path to a `.md` file. Defaults to `--person 1`
(Nick Shook — the local dev identity). The database is pre-seeded with example
answers for common questions.

```bash
# By seeded template code
navigator notation trusts__nevada --entity 1

# By file path (code is derived from the Examples/ directory structure)
navigator notation Sources/NavigatorDAL/Examples/Trusts/nevada.md --entity 1

# Person-type template — person defaults to 1, no flag needed
navigator notation <person-template-code>

# Person-and-entity template
navigator notation <template-code> --entity 1
```

**Respondent types:**

- `entity` templates require `--entity <id>`
- `person` templates default to `--person 1` (Nick Shook)
- `person_and_entity` templates default person to 1, require `--entity <id>`

**What it does:**

1. Resolves the template by code or file path
2. Walks the questionnaire state machine, prompting for each question
3. Upserts each answer into the `answers` table (deduplicates by question + person + value)
4. Interpolates `{{question_code}}` placeholders in the markdown content
5. Creates the `Notation` and prints its ID and initial workflow state

**Example output:**

```text
Who is the trustee?
  (The person must pre-exist as a person record within Neon Law.)
> Nick Shook
Created notation #1 — state: staff_review
```

**Seeded templates:**

| Code | Title | Respondent |
|------|-------|-----------|
| `trusts__nevada` | Nevada Trust | entity |

List all available templates with `navigator list templates`.

### `navigator pdf <file>`

Validates and converts Markdown file to PDF. Strips frontmatter.

```bash
navigator pdf nevada.md  # Creates nevada.pdf
```

**Requirements:**

- Valid frontmatter with `title` field
- Lines ≤120 characters
- `pandoc` installed: `brew install pandoc`

## Architecture

The Navigator project is organized into three main Swift Package Manager targets:

### NavigatorRules

Lightweight validation rules library with zero external dependencies.

- **Location**: `Sources/NavigatorRules/`
- **Purpose**: Shared validation logic for markdown files
- **Dependencies**: None (Foundation only)
- **Key Components**:
  - `Rule` protocol - Defines validation rules
  - `FixableRule` protocol - Rules that can auto-fix violations
  - `Violation` types - Structured error reporting
  - `FrontmatterParser` - YAML frontmatter parsing utility
  - Rule implementations (F101, F102, S101, M001–M060)
  - `RuleEngine` - Orchestrates rule execution across files
  - `FileFilters` - Markdown file inclusion/exclusion gate
  - `NavigatorDefaultRules.all()` - Canonical rule set factory

#### Extending Navigator's rules

Downstream Swift CLIs that want to layer additional rules onto
Navigator's defaults can depend on `NavigatorRules` directly and use
the `NavigatorDefaultRules.all()` factory plus the `RuleEngine` and
`FileFilters` types — no boilerplate copying required:

```swift
import NavigatorRules

let rules = NavigatorDefaultRules.all() + [C001_NoEmoji(), C002_RequireAuthor()]
let engine = RuleEngine(rules: rules)
let result = try engine.lint(directory: url)
```

[Compass](https://github.com/neon-law-foundation/Compass) is the
reference downstream of this seam: it depends on `NavigatorRules`,
exposes `CompassDefaultRules.all()` as a strict superset of
`NavigatorDefaultRules.all()`, and ships the `compass` CLI for
Foundation-specific rules (e.g., `C001_RequireCompassFooter`). Custom
rules implement the `Rule` (or `FixableRule`) protocol and can reuse
the parsing utilities (`FrontmatterParser`, `BlockTokenizer`,
`LineScanner`, etc.) already published by `NavigatorRules`.

### NavigatorDAL

Data Access Layer using Fluent ORM for database operations.

- **Location**: `Sources/NavigatorDAL/`
- **Purpose**: Database models, migrations, and services
- **Dependencies**: Fluent, FluentPostgresDriver, FluentSQLiteDriver, Vapor, NavigatorRules
- **Key Components**:
  - Fluent models (Notation, Entity, Person, etc.)
  - Database migrations
  - Service layer (NotationService, NotationValidator)
  - Repositories for data access
  - Validation at model layer using NavigatorRules

**Validation Strategy:**

The DAL validates data using Swift code (not database constraints) following
Fluent best practices:

- Database constraints: Only for referential integrity (foreign keys, uniqueness)
- Swift validations: For business rules (format, content, relationships)
- Better error messages and type safety
- Cross-database compatibility (SQLite, PostgreSQL)

### NavigatorApp (the `neonlaw.org` website)

The Vapor executable that serves the public Neon Law Foundation site.

- **Location**: `Sources/NavigatorApp/`
- **Purpose**: Renders the NLF home, blog, workshop, about, contact,
  privacy, and terms pages; serves static assets from `Public/`.
- **Dependencies**: Vapor, VaporElementary, Elementary, swift-markdown,
  NavigatorWeb.
- **Key Components**:
  - `Entrypoint.swift` — `@main` boot.
  - `configure.swift` — port, `FileMiddleware`, blog/workshop loaders.
  - `routes.swift` — every public route.
  - `BlogLoader.swift` / `WorkshopMaterialsLoader.swift` — read
    `Sources/NavigatorApp/Content/Blog/*.md` and
    `Public/workshops/claude-code-zodiac/*.md` into memory at startup.
  - `Views/*.swift` — Elementary page components; shared UI pieces
    live in `NavigatorWeb`.

Run it locally:

```bash
swift run NavigatorApp       # or: make dev
```

The server listens on `http://localhost:3001`.

### NavigatorCLI

Command-line interface for linting and importing notations.

- **Location**: `Sources/NavigatorCLI/`
- **Purpose**: Interactive CLI tools
- **Dependencies**: NavigatorRules, NavigatorDAL, Logging
- **Key Components**:
  - `LintCommand` - File validation
  - `ImportCommand` - Database import
  - `PDFCommand` - PDF generation
  - `QuestionsListCommand` - List seeded questions
  - `JurisdictionsListCommand` - List seeded jurisdictions
  - `DatabaseManager` - In-memory SQLite management
  - `NotationImporter` - Markdown to database importer

**Dependency Flow:**

```text
NavigatorCLI
    ├── NavigatorRules (validation)
    └── NavigatorDAL (persistence)
            └── NavigatorRules (validation)
```

This architecture enables:

1. **Code Reuse**: Same validation rules in CLI and DAL
2. **Single Source of Truth**: Rules defined once, used everywhere
3. **Testability**: Each layer tested independently
4. **Type Safety**: Swift compiler enforces correct usage

## Initial Setup

Before using the `navigator` CLI commands, you need to set up your `~/Navigator`
directory structure. This is typically done using a setup script in `~/.navigator/`:

### `~/.navigator/` Directory

The `~/.navigator/` directory contains:

- **`setup.sh`** - Shell script to initialize `~/Navigator` and clone project repositories
- **`CLAUDE.md`** - Style guide template for legal contract writing
- **`.claude/`** - Claude Code configuration (agents, commands, etc.)

### Running Setup

```bash
# Initialize ~/Navigator directory and clone all project repositories
~/.navigator/setup.sh
```

This setup script will:

1. Create the `~/Navigator` directory if it doesn't exist
2. Clone or update git repositories from configured sources
3. Copy the CLAUDE.md style guide to `~/Navigator/CLAUDE.md`

**Note:** The setup script should be customized with your specific repository
URLs and access credentials. Contact your administrator for the appropriate
configuration.

## Development

Build the project:

```bash
swift build
```

## Platform Support

NavigatorCLI supports **macOS and Linux only**. Windows is not currently supported.

The blocking issue is [apple/swift-nio#2065](https://github.com/apple/swift-nio/issues/2065) —
SwiftNIO does not build on Windows. Since NavigatorDAL depends on Vapor, which depends on SwiftNIO,
the entire CLI is blocked until that upstream issue is resolved.

## Homebrew Distribution

Releases are published weekly at Sunday 02:00 UTC via
`.github/workflows/weekly-release.yaml`. The workflow builds arm64, x86_64,
and universal macOS binaries, creates a GitHub release with checksums, and
updates `Formula/navigator.rb` in
[neon-law-foundation/homebrew-tap](https://github.com/neon-law-foundation/homebrew-tap) —
the actual GitHub repository behind `brew tap neon-law-foundation/tap`.

© 2026 Neon Law Foundation.
