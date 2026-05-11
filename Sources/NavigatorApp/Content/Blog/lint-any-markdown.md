---
title: "Lint any Markdown with navigator"
author: ""
description: "A new --markdown-only flag in the navigator CLI checks any Markdown file, not just legal notations."
slug: "lint-any-markdown"
---

Navigator is an open-source CLI for checking legal documents. A new
flag lets it check the formatting of any Markdown file — READMEs,
internal memos, anything that ends in `.md` — not just the structured
legal templates (we call them notations) it was built for.

```bash
navigator lint --markdown-only ./docs
```

That's it. One flag, same install. The check runs the general Markdown
rules — line length, heading style, list indentation, table layout —
and skips the legal-template-specific rules.

If you want it to fix what it can — wrapping long lines at the nearest
whitespace boundary — add `--fix`:

```bash
navigator lint --markdown-only --fix ./docs
```

macOS and Linux. The Navigator repository on GitHub has install
instructions for both.
