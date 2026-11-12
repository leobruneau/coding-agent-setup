# Per-item workflow and role briefs (written by root)

RUN = <RUN_DIR>. Every role reads RUN/MISSION.md "Hard rules" first<, and the writing rules in <path>>.
Nobody answers questions during the run: decide yourself, pick the simplest option that is robust and
easy for a human to review, and write the decision down with its reason. Subagents never commit, push or
write to outside systems; the orchestrator does that after review. Work only in the item's worktree
RUN/worktrees/<item>.

Write your report to the file your brief names, before you reply, because the orchestrator may hand off
before you finish and the next one reads the file. Reply in 150 words or fewer (reviewers: 30 words) and
name the file.

## Skill files

<Background sessions can't always load plugin skills with the Skill tool. If it fails, read the file and
follow it by hand. Where a skill asks the user a question or publishes to a tracker, the orchestrator
answers with a logged decision and the output goes to files.>
- <skill name>: <absolute path to its SKILL.md>

## Steps per item (the orchestrator runs these)

1. Read the item and its current state. Pick the path (e.g. light for a small fix with one obvious
   approach, full for a real design choice, split for an item too big for the run) and log it with the
   reason.
2. Create the worktree with `RUN/tools/new_wt.sh <item> <slug>`, one at a time.
3. <the role steps for each path, with the files each writes>
4. Review: read the diff against how the user will use the change. Run `RUN/tools/<checks script>`. For
   changes the user sees, run the app and look. Fix small problems yourself, or send a fix to a subagent.
5. <how the change leaves the workspace: commit message rules, push, change request body, attribution>.
   Record the files touched in the item's PLAN.md note and mark it done.

## <Role, e.g. designer, reviewer, spec writer, implementer, lead>

1. <what to read>
2. <what to decide and write, with the output file path under RUN/results/>
3. <commands that must pass>
4. Report file: <path>. Reply: <limit>.

## Resolution policy for review findings

- Accept every finding that fixes a wrong claim about the code, a bug, a missing or broken test, or an
  ambiguity.
- Reject findings that add scope beyond the item, new dependencies or refactors the fix doesn't need; say
  why.
- When two findings conflict, pick the simpler option that is still correct.
- A finding that changes the behaviour the user asked for, or that this policy can't settle: don't
  decide. List it in your report for the orchestrator to decide and log.

## Rules for every change

- <project rules that apply to every change, e.g. files nobody but one item may edit, no key-shaped
  literals, new tests in new files so branches don't collide>
