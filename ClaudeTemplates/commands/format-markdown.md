# Format Markdown

## Usage

```txt
/format-markdown
```

Format markdown files or those ending in `.md` with these steps.

1. Run `navigator lint .` to surface every violation in the tree.
2. For each file with line-length, bullet-style, or trailing-whitespace
   violations, run `navigator format <file>` to auto-fix them.
3. Fix any remaining violations by hand. Confirm with the developer if you are
   unsure how to fix an issue.
4. Re-run `navigator lint .`. **MANDATORY** this must exit 0.
