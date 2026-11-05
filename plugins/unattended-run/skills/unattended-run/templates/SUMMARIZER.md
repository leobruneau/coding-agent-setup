# Final summary brief (read-only: never edit this file)

Written by orchestrator root on <DATE TIME>. You are the final summary session ("<TAG> | FS") of <RUN_NAME>. Review
every orchestrator session and write one summary for the user. Do no new work on the task itself.

## Read first
<RUN_DIR>/MISSION.md has the goal in the user's words, the stop condition and the rules. Its rules apply
to you. Take only the outside actions it allows.

## Steps
1. Make sure the run has stopped. If LOG.md has no `run stopped` line, run `<RUN_DIR>/tools/stop_work.sh`.
   Check that no job or process named `<PREFIX>...` is still running, and stop leftovers. Check that no
   orchestrator is still working (`claude agents --json`) and `claude stop <id>` any that is.
2. Review the sessions. LOG.md has a `launch orchestrator N <id>` line for each. For each orchestrator:
   time span, what it did, what it concluded, problems, whether it handed off cleanly or needed recovery.
   Use `claude logs <id>` where LOG.md is thin.
3. Read the results: SUMMARY.md, PLAN.md and the outputs they cite. If SUMMARY.md is missing, say so and
   work from PLAN.md, LOG.md and `results/`. Check numbers and claims against the raw files and LOG.md,
   and note mismatches. State whether the stop condition was met, or which backstop ended the run.
4. Write FINAL_SUMMARY.md in the run directory, about one page:
   - the goal in one sentence, the stop condition and what ended the run;
   - what was done (counts, method, limits met along the way);
   - results with evidence (tables, numbers, links to issues or commits);
   - what worked, what didn't, how sure, what still needs checking;
   - each of the user's ideas from MISSION.md and what the run says about it;
   - blocked items and their reasons;
   - orchestrator timeline: session name ("<TAG> | O<N>"), session id, span, main actions, problems;
   - open items, next steps, uncommitted or unreviewed changes.
5. Append `- <date time> final summary written` to LOG.md, then stop. Your last message: headline findings
   in 150 words or fewer and the path to FINAL_SUMMARY.md.
