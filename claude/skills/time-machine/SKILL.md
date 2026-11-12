---
name: time-machine
description: >-
  Trace back and report on work done over a past period by mining stored Claude
  Code history (and git history where a repo exists). Use this whenever the user
  wants to know what they did/worked on/accomplished/changed over a time window
  — phrasings like "what did I do last week", "summarize my work this month",
  "write up what I got done on <project> since <date>", "recap the last sprint",
  "progress report across my projects", "what happened in <repo> in June",
  standups, retros, status updates, or any look-back over recent work. Triggers
  for a single project, several projects, or all projects at once. Reach for it
  even when the user doesn't say "report" — any request to reconstruct or track
  past progress over time is this skill.
disable-model-invocation: true
---

# Time Machine

Reconstruct what was actually worked on over a past time window and write it up
as a plain, detailed report. The truth lives in two places: Claude Code's stored
session transcripts, and (for projects that are git repos) the commit history.
This skill reads both and turns them into one dry, readable account of progress.

## How the data is laid out

Claude Code keeps one JSONL transcript per session under
`~/.claude/projects/<encoded-cwd>/<session>.jsonl`. Each line records a
timestamp, the working directory, the git branch, and a message (a user prompt,
Claude's reply, or a tool action). One "project" = one working directory. A
project may be a git repo; the git log adds commit-level detail the transcripts
don't capture (e.g. work done outside Claude, or squashed into clean commits).

You don't parse the JSONL by hand — `scripts/extract.py` does that for you.

## Workflow

### 1. Settle the scope and the window

Two things define a run: **which projects** and **what time window**.

- Project: a single one, a named few, or all. If the user names a project, pass
  it as a `--project` substring filter. If they say "everything" / "all my
  projects" / "across projects", run with no project filter.
- Window: inclusive dates. If the user gives one ("last week", "since the 1st",
  "in June"), convert it to concrete dates (today's date is in your context).
  If they give none, default to the **last 7 days** and say so in the report.

Don't stall asking — pick the sensible reading, state the scope and window at
the top of the report, and proceed. The user can correct a wrong guess faster
than they can answer a question up front.

### 2. See what's there

```bash
python3 ~/.claude/skills/time-machine/scripts/extract.py --list
```

This lists every project in history with its session count, active date range,
and whether it's a git repo. Use it to confirm the scope and to spot projects
the user might mean but didn't name precisely.

### 3. Pull the transcript digest

```bash
# focused: one project, full detail (prompts + Claude's summaries + every action):
python3 ~/.claude/skills/time-machine/scripts/extract.py --since 2026-06-01 --until 2026-06-15 --project harmonic-tension

# wide: many projects / long window, compact (--brief):
python3 ~/.claude/skills/time-machine/scripts/extract.py --days 30 --brief
```

`--project` is repeatable and matches a substring of the project path. `--days
N` is shorthand for the last N days. Output is grouped by project, then by
session, showing the user's prompts, Claude's own summaries, and the concrete
actions taken (files read/edited/written, commands run, tools used).

**Match the mode to the scope so you don't drown in tokens.** Full mode is rich
but large (a busy project-month can run tens of thousands of tokens). `--brief`
drops Claude's prose summaries and collapses actions to a touched-file list plus
a command count — small enough to scan many projects at once.

A good default for wide scopes: run `--brief` across everything first to see the
shape of the period and where the work concentrated, then re-run full mode on
the one or two projects that matter for detail. For a single named project, full
mode directly is usually fine. If even a single project's full digest is too big
to take in, fall back to `--brief` for it and pull raw transcripts only where
needed.

If a session looks pivotal but the digest is too terse, read the raw transcript
at the path the digest prints for that session. Don't do this for everything —
only when a specific piece of work is unclear and matters to the report.

### 4. Add git history for repo projects

For every project the digest marks as a git repo, get the commit-level view —
this catches work across **all branches**, not just the one Claude sat on:

```bash
git -C <project-cwd> log --all --since=<start> --until=<end> \
    --pretty=format:'%h %ad %an %d %s' --date=short
```

Then, for branches or commits that look central to the period, drill in with
`git -C <cwd> show --stat <sha>` or `git -C <cwd> log --all --stat --since=...`
to see which files moved and by how much. Note merges, branch topology, and any
commits that don't correspond to anything in the transcripts (work done outside
Claude) — those still belong in the report.

### 5. Write the report

Synthesize the digest and git history into one account. Write the file, then
give the user a short summary in chat (see Output).

## Report style

Dry, simple, clearly understandable. State what was done, when, and why it
mattered — in the order it happened. No marketing adjectives, no "successfully",
no padding. Prefer concrete nouns (file names, features, bugs, commit subjects)
over vague ones ("various improvements"). If the work is unclear or you're
inferring intent, say so plainly rather than dressing it up. A reader should be
able to skim it and know exactly what moved.

Group by project. Within a project, narrate chronologically — that's how
progress reads. Don't invent structure the work doesn't have.

## Report structure

Use this template. Drop sections that don't apply (e.g. omit "Commits" for a
non-git project, omit the cross-project roll-up for a single project).

```markdown
# Work report — <scope> · <start> to <end>

Scope: <which projects, and the window; note if the window was defaulted>.
Sources: Claude Code session history<, and git history for N repo(s)>.

## Summary
<3–6 plain sentences: the main things that got done across the whole window.>

## <Project name / path>
Active: <dates> · Branches touched: <list> · Sessions: <n>

### What was done
<Chronological account. Each entry: what changed and why. Group naturally by
day or by piece of work — whichever the activity suggests. Name the files,
features, and bugs involved.>

### Commits   <!-- only for git repos -->
<Notable commits across all branches in the window: short sha, date, subject,
and the files/area they touched. Flag commits with no matching transcript.>

### State at end of window
<Where things stood when the window closed: what's finished, what's in
progress, what's left open or broken.>

## Cross-project notes   <!-- only when several projects -->
<Themes spanning projects, where time concentrated, anything notable about how
the work split across them.>
```

## Output

Write the report to `~/time-machine-reports/` with a descriptive, timestamped
name, e.g. `~/time-machine-reports/2026-06-29_harmonic-tension_jun.md` (create
the directory if needed). Then print a short summary in chat — a few sentences
on what the period covered — and the path to the full file. Don't paste the
whole report into chat; that's what the file is for.

## Notes

- Subagent (sidechain) chatter is filtered out of the digest on purpose — the
  main thread already reflects its outcomes, and including it doubles the noise.
- Resumed/continued sessions replay earlier messages; the script dedupes them by
  message id, so you won't see (or have to manually collapse) the same work
  twice. Trust the digest as already deduped.
- A project's history directory name is the working directory with `/` replaced
  by `-`, but paths can themselves contain `-`, so the script reads the real
  `cwd` from inside each transcript rather than decoding the directory name.
  Trust the `cwd` the script reports.
- If `--list` shows nothing, there's no history at `~/.claude/projects/` — say
  so rather than guessing.
