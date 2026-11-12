# Final summary brief (read-only: never edit this file)

Written by orchestrator root on <DATE TIME>. You are the final summary session ("<TAG> | FS") of
<RUN_NAME>. Review every orchestrator session and write one summary for the user. Do no new work on the
task itself. The user will open this session when they come back and keep working in it, so it ends with
everything they need to act.

## Read first
<RUN_DIR>/MISSION.md has the goal in the user's words, the stop condition and the rules. Its rules apply
to you. Take only the outside actions it allows. If you need a checkout, use a detached worktree, so you
never hold a branch the user wants to check out.

## Steps
1. Make sure the run has stopped. If LOG.md has no `run stopped` line, run `<RUN_DIR>/tools/stop_work.sh`.
   Check that no job or process named `<PREFIX>...` is still running, and that nothing still listens on
   the run's ports. Run `<RUN_DIR>/tools/sessions.sh` and keep its `! claude stop` lines for step 4. Don't
   run `claude stop` yourself: the permission check refused it in every run so far.
2. Review the sessions. LOG.md has a `launch orchestrator N <id>` line for each. For each orchestrator:
   time span, what it did, what it concluded, problems, whether it handed off cleanly or needed recovery.
   Where LOG.md is thin, read the session's transcript (`~/.claude/projects/*/<session id>*.jsonl`).
   `claude logs` returns screen text that was no use in earlier runs.
3. Read the results: SUMMARY.md, PLAN.md and the outputs they cite. If SUMMARY.md is missing, say so and
   work from PLAN.md, LOG.md and `results/`. Check numbers and claims against the raw files, the tracker
   and LOG.md, and note mismatches. State whether the stop condition was met, or which backstop ended the
   run. List the side effects of merging the results: new workflows or bots, schedules that start on
   deploy, required settings or keys, migrations, issues that will close, new issues the run opened.
   Before you recommend a step such as retargeting a change, check that it can still work.
4. Write FINAL_SUMMARY.md in the run directory, about one page plus tables:
   - the goal in one sentence, the stop condition and what ended the run;
   - what was done (counts, method, limits met along the way);
   - results with evidence (tables, numbers, links to issues or commits);
   - what worked, what didn't, how sure, what still needs checking by hand;
   - each of the user's ideas and setup answers from MISSION.md and what the run did with it;
   - blocked items and their reasons;
   - orchestrator timeline: session name ("<TAG> | O<N>"), session id, span, main actions, problems;
   - "When you return": merge order, deploy steps and settings, the side effects from step 3, and
     paste-ready commands for what the run could not do itself (the `! claude stop` lines from step 1,
     superseded changes to close, worktrees and scratch branches to remove once merged).
5. Append `final summary written` to LOG.md with `<RUN_DIR>/tools/log.sh "final summary written"`, then
   stop. Your last message: headline findings in 150 words or fewer and the path to FINAL_SUMMARY.md.

## When the user comes back
Answer from the run directory first. If they ask for a review of the results, use fresh subagents that
didn't write the code, one per area. If they ask for follow-up fixes or a combined change, those are new
work: log them in LOG.md with `tools/log.sh` so the run directory stays the record.
