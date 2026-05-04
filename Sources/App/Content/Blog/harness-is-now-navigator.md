---
title: "Harness is now Navigator"
date: "2026-04-19"
author: "Neon Law Foundation"
description: "We renamed our legal standards library from Harness to Navigator. Here's what changed and what didn't."
tags: ["announcements", "open-source"]
slug: "harness-is-now-navigator"
---

We renamed our legal standards library. **Harness is now Navigator.**

The new repository lives at
[github.com/neon-law-foundation/Navigator](https://github.com/neon-law-foundation/Navigator).
The CLI binary, the Swift package, and the Homebrew formula all use the
`navigator` name.

## Why the rename

"Harness" reads like a testing utility. The library isn't a test harness;
it's a legal standards library — rules, enumerations, and middleware that
help an attorney or an application reason about legal structure. "Navigator"
names what it does: it helps you find your way through the standards.

## What changed

- Repository: `neon-law-foundation/Harness` → `neon-law-foundation/Navigator`
- Swift package: `Harness` → `Navigator`
- Modules: `HarnessDAL` → `NavigatorDAL`, `HarnessRules` → `NavigatorRules`,
  `HarnessOIDCMiddleware` → `NavigatorOIDCMiddleware`
- CLI: `harness` → `navigator`
- Homebrew: `brew install neon-law-foundation/tap/navigator`

## What didn't change

The public API is identical. Type names, function signatures, and behavior
are unchanged — only module and package names differ. Upgrading is a
rename in your `Package.swift` and your imports.

## Getting it

Swift Package Manager today:

```swift
.package(url: "https://github.com/neon-law-foundation/Navigator.git",
         from: "0.1.0")
```

Our weekly release workflow publishes signed macOS binaries and refreshes a
Homebrew formula in `neon-law-foundation/homebrew-tap`. The next cut on
Sunday 2026-04-26 will replace the old `harness` formula with `navigator`,
and `brew install neon-law-foundation/tap/navigator` will work from then on.

## No transition period

We didn't keep a `Harness` alias. The old name is gone. If you depended on
the previous repository URL, update your `Package.swift` to point at
`Navigator.git` and refresh with `swift package update`.

Questions? Email <support@neonlaw.org>.
