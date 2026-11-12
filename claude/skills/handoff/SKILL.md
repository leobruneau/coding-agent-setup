---
name: handoff
description: >-
  Write a detailed handoff document so a fresh agent with empty context can pick
  up the current task without redoing work, then start that fresh session with
  the handoff already loaded. Use this whenever the user signals a context
  boundary is coming — "write a handoff", "hand this off", "I'm running low on
  context", "context is almost full", "/compact won't cut it", "start a new
  session but keep the state", "brief the next agent", "clean slate but don't
  lose where we are", "pick this up tomorrow", "pause here and write up where we
  are". Reach for it even when the user doesn't say the word "handoff": any
  request to preserve in-flight task state across a context reset, session
  restart, or day boundary is this skill.
disable-model-invocation: true
---

# Handoff

Write the document a competent stranger needs to take the *next* action on this
task correctly — without repeating your dead ends and without re-litigating
decisions the user already made.

A handoff is not a summary of the conversation. Compaction already produces a
lossy summary, and what it drops is precisely what's expensive: the paths that
failed and *why*, the constraints the user stated once in passing, the
half-formed hypothesis you were about to test. Those took real tokens and real
wall-clock to earn. Everything a fresh agent can cheaply re-derive by reading a
file or running `git log` does not belong here.

The successor will trust this document completely and will not have the
transcript to check it against. That makes a confident wrong claim in a handoff
much more damaging than an omission — mark what you verified as verified, and
what you assumed as assumed.

## 1. Gather facts before writing

Your recollection of a long session is lossy in the exact places that matter
(which fix landed, which was reverted, whether that test actually passed). Spend
a few tool calls re-grounding first, in parallel:

- `git status --short` and `git log --oneline -10` — what actually landed vs what
  is still uncommitted. Note the branch and whether you're in a worktree.
- `git diff --stat` (and `git diff` on the files you touched) — the real shape of
  the change, not the shape you intended.
- Re-read the user's original request, verbatim, wherever it appears in the
  conversation. Handoffs drift toward what you *did* and away from what was
  *asked*; the successor needs the ask.
- Check anything still running: background jobs, `sbatch`/`squeue` job IDs, open
  PRs, servers you started. An orphaned process the successor doesn't know about
  is a nasty surprise.
- Re-check your last claim of success. If you said a test passed, confirm it
  still does, or say plainly that it passed once and hasn't been re-run.

## 2. Write it

Save to `~/.claude/handoffs/<project-slug>/<YYYY-MM-DD-HHMM>-<topic>.md`, where
`<project-slug>` is the absolute cwd with every `/` replaced by `-` (so
`/home/u/repo` → `-home-u-repo`) — the same convention Claude Code uses for its
own project dirs, and what the resume hook in step 3 looks for. Keep handoffs out
of the repo checkout so they never show up in `git status`. Create the directory
with `mkdir -p`.

Use this structure. Drop sections that are genuinely empty rather than padding
them with "N/A" — but "no dead ends" and "no user decisions" on a long session
usually means you didn't look hard enough.

```markdown
# Handoff: <topic in one line>

Written <date time> · cwd `<absolute path>` · branch `<branch>`<, worktree>
Model/session context: <anything unusual — bg job, ponytail mode, plan mode>

## The ask
<The user's actual request, in their framing. Quote the key sentence if short.
If the scope was renegotiated mid-session, say what it is NOW and what changed.>

## Where things stand
- **Done and verified:** <thing> — verified by `<command>` / <observation>
- **Done, unverified:** <thing> — <what check is still owed>
- **In flight:** <thing> — <exactly how far it got>
- **Not started:** <thing>

## Anchors and map
<The 3-8 files that matter, with line numbers: `path/to/file.py:120-160` — what
lives there and why it matters *for this task*. Plus job IDs, PR/branch URLs,
output dirs, config names.>

<Then the understandings that cost you tool calls to earn: the call path you
traced end to end, where the real logic lives versus where it looks like it
lives, which of two similarly-named files is the live one, the invariant you
inferred, the gotcha that isn't written in any comment, the search that came
back empty (`no other caller of X` is a finding). This is the part that saves
the successor the most reading.>

## How to verify / reproduce
<Exact commands, copy-pasteable, in order. Include the setup that isn't
obvious: env vars, container paths, which host to run on. If the successor's
first move is to reproduce a failure, give the command that fails and the
error it prints.>

## Dead ends — do not redo
<Each: what was tried, what happened, and the inference. The inference is the
valuable part: "raising the timeout can't help, the process is genuinely dead"
is worth more than "tried raising timeout, didn't work".>

## Decisions and constraints from the user
<Choices the user made, with their reasoning where you know it, and hard
constraints they stated. This is what stops the successor from cheerfully
proposing the approach the user already rejected. Include preferences that
sound minor — they were stated for a reason.>

## Working hypothesis
<What you currently believe is going on, how confident you are, and what
evidence would confirm or kill it. Say "unknown" if you don't have one; a
fabricated hypothesis sends the successor down a false trail.>

## Next action
<One concrete first move, specific enough to execute without deciding anything:
the file to edit, the command to run, the question to answer. Then a short
ordered list of what follows.>

## Open questions for the user
<Anything you'd have asked if the session had continued. Flag which ones block
progress and which can be assumed past.>
```

**What earns a place in the map:** ask whether learning it cost you tool calls,
and whether it's still true. Working out which of four `load_config` call sites
actually runs is expensive; the body of `load_config` is one `Read` away. Write
down the *conclusions* of your searching, not the material you searched — a
successor who opens exactly the right three files at the right line ranges has
inherited an hour of your reading for the price of a paragraph. Paste code only
when the successor needs the exact current text to reason about a change that
hasn't been made yet; otherwise a path and line range is strictly better,
because a quoted snippet silently goes stale and a path cannot.

Write for an agent reader: paths over prose, exact commands over descriptions of
commands, no hedging and no preamble. Length follows the work — a two-hour
debugging session earns a page; a small feature earns a few paragraphs. Padding
costs the successor context, which is the one thing this whole exercise exists
to conserve.

## 3. Start the fresh session

Print the path, then offer both routes. Don't run `claude` yourself from a tool
call — a nested subprocess isn't a session the user can talk to.

**Route A — new terminal, handoff as the opening message** (nothing to install):

```bash
claude "$(cat ~/.claude/handoffs/<slug>/<file>.md)"
```

Tell the user they can paste that directly, or prefix it with `!` in the Claude
Code prompt if they want the command to run in this session's shell.

**Route B — stay in this terminal, `/clear`, handoff auto-injected**: a
`SessionStart` hook points the fresh session at the newest unconsumed handoff
and tells it to `Read` the file, then marks it consumed so it never leaks into
later sessions. It deliberately does *not* `cat` the handoff into stdout: Claude
Code persists hook output over ~10KB to disk and shows the model only a 2KB
preview, which silently truncates any handoff worth writing.
`scripts/resume_hook.sh` in this skill does that. Install (idempotent, edits
`~/.claude/settings.json` via `python3` — read the script before running it):

```bash
bash ~/.claude/skills/handoff/scripts/install_hook.sh
```

Once installed, the flow is: run this skill → `/clear` → the fresh agent opens
with the handoff already in context. Offer the install once; if the user
declines, Route A covers everything.

## Notes

- If the user wants the handoff for a *human* (a colleague, their future self
  next week) rather than an agent, keep the same structure but expand the "why"
  and drop the copy-pasteable-command density — say what you're doing and let
  them redirect you.
- A handoff naming a file, function, or flag that no longer exists is worse than
  no handoff. Verify anchors exist before writing them down.
- Worth saving to memory instead of the handoff: durable facts about the user,
  the project, or a root cause that will still be true next month. The handoff
  is for the perishable state of *this* task.
