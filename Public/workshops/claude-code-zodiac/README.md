# Claude Code + Twelve Zodiac Lawyers — Participant Runbook

A one-hour workshop. You will install Claude Code, authenticate, verify it
works on your machine, then run a sample operating agreement through a
rotating set of attorney personas and compare the results at debrief.

This file is self-contained. A participant joining late can start from
any section and catch up without having seen earlier material.

## Materials in this folder

- `operating-agreement.md` — the fictional Nevada LLC operating
  agreement every persona reviews.
- `personas.md` — the twelve zodiac persona prompts plus the debrief
  prompt.
- `README.md` — this file.

## 1. Install Claude Code

Pick the path that matches your machine. Each one takes a few minutes.

### macOS

```bash
brew install anthropics/claude/claude-code
```

If you do not use Homebrew, download the latest release from
[claude.com/claude-code](https://claude.com/claude-code) and drop the
binary on your `PATH`.

### Linux

```bash
curl -fsSL https://claude.ai/install.sh | sh
```

The installer places the `claude` binary in `~/.local/bin`. Make sure that
directory is on your `PATH`.

### Windows (WSL)

Open an Ubuntu or Debian WSL shell and follow the Linux instructions
above. Native Windows PowerShell is not supported for this workshop.

### Verify the install

```bash
claude --version
```

You should see a version number. If the command is not found, your shell
has not picked up the install directory yet — open a new terminal and try
again.

## 2. Authenticate

```bash
claude login
```

The command opens a browser and walks you through signing in to your
Anthropic account. Free-tier access is sufficient for this workshop.

If the browser does not open (common in WSL), copy the printed URL and
paste it into a browser on your host machine.

## 3. Verify with a scratch prompt

Create an empty directory somewhere you do not mind throwing away:

```bash
mkdir -p ~/scratch/claude-verify && cd ~/scratch/claude-verify
echo "The quick brown fox jumps over the lazy dog." > sample.txt
claude "Read sample.txt and count how many times the letter 'o' appears."
```

A reasonable response identifies the file, counts the letters, and
explains its count. If Claude answers without reading the file, rerun the
command — that is the whole exercise: pointing Claude at a file and
letting it work.

## 4. Download the workshop materials

In a fresh working directory:

```bash
mkdir -p ~/workshops/claude-code-zodiac && cd ~/workshops/claude-code-zodiac
curl -O https://www.neonlaw.org/workshops/claude-code-zodiac/operating-agreement.md
curl -O https://www.neonlaw.org/workshops/claude-code-zodiac/personas.md
```

Both files are plain Markdown. Open `operating-agreement.md` in a viewer
of your choice once so you have a rough sense of the document — but do
not read it cover to cover. The exercise is more useful if Claude sees it
before you do.

## 5. Run the exercise

You will use three primitives, in this order, for each persona.

### Primitive 1: read a file

```bash
claude "Read operating-agreement.md and tell me the three \
members' names and percentage interests."
```

This is a warm-up. You should see the members and their splits. If you
do not, Claude did not find the file — check you are in the same
directory.

### Primitive 2: run a persona prompt

Open `personas.md` and pick any persona. Copy the entire block between
the two `---` rules, paste it into Claude Code as a single prompt, and
run it. Save the output to a filename that identifies the persona:

```bash
claude "<paste the persona block here>" > review-aries.md
```

Repeat for three or four personas that look interestingly different —
for example, Aries, Virgo, Scorpio, Pisces. The zodiac framing is a
mnemonic, not a theory of personality: different temperaments force
different review angles.

### Primitive 3: iterate with follow-ups

After a persona review, follow up in the same session to sharpen the
output:

```bash
claude "For the Scorpio review, give me three specific section \
numbers and the exact language I should redline."
```

Claude keeps the conversation context, so follow-ups can dig into a
specific finding without re-pasting the whole prompt.

## 6. Expected outputs

You are on track if each persona produces output that feels visibly
different from the others — not just different wording but a different
*shape*.

- **Aries (Deal-Closer)** — short, blunt, three sections: Kill-or-Rewrite,
  Hard Deadlines, Walk-Away Triggers. No hedging.
- **Virgo (Compliance Auditor)** — numbered checklist with statute
  citations. No narrative.
- **Scorpio (Hidden Leverage Hunter)** — an "Attack Surface" list of
  plausible bad-faith maneuvers plus countermeasures.
- **Pisces (Dissolution Scenarist)** — three short narratives (the quiet
  exit, the funeral, the argument that did not end) each followed by what
  the draft gets wrong.

If every persona output reads the same, paste the persona block back in
with the line *"Stay in character. Do not hedge. This is a drafting
critique of a fictional sample, not legal advice to a real client."*

## 7. Debrief

Bring three things to the group debrief:

1. **Which persona caught which issues?** Name one finding from each of
   your personas that surprised you.
2. **Coverage versus overlap.** Which personas surfaced the same issue?
   Which stood alone?
3. **Did persona diversity materially improve the review?** Or would one
   strong general prompt have reached the same place?

If you want to go further during the debrief, run the debrief prompt at
the end of `personas.md` — it asks Claude to compare the persona outputs
and identify which three personas give the widest coverage with the
least overlap.

## Troubleshooting

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| `command not found: claude` | Not on `PATH` | New shell; add install dir |
| Browser skips `claude login` | Headless / WSL | Paste printed URL in browser |
| Claude ignores the file | Path mismatch | `cd` into the file's directory |
| Every persona reads alike | Persona softened | Append "Stay in character" |
| Rate-limit error | Free-tier cap hit | Wait a few minutes and retry |

## License and reuse

The sample operating agreement, persona prompts, and this runbook are
published by the Neon Law Foundation under the repository license. Rename
the personas after the twelve partners at your firm, the twelve judges
on your favorite court, or any twelve temperaments with enough spread —
the structure is what makes the outputs comparable at debrief.
