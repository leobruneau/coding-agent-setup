# Coordinator notes (orchestrators update this)

Read MISSION.md first. It holds the goal, the stop condition, the rules and the handoff procedure, and it
wins over this file. This file holds facts, tools and lessons that change during the run, and the current
State. Keep it short: every orchestrator reads all of it at startup.

## Facts
- <what limits throughput, time per unit of work, baseline check times, slow commands and how to run them>

## Tools in the run directory
- `tools/launch_orchestrator.sh <N> [recovery]`, `tools/launch_summary.sh`, `tools/stop_work.sh`,
  `tools/run_at.sh`, `tools/watchdog.sh`, `tools/start_timers.sh`, `tools/log.sh`, `tools/sessions.sh`,
  `tools/ctx`, `tools/setsid`: see the skill's SKILL.md, "Scripts".
- <the run's own scripts: what each does, arguments, outputs. Orchestrators add theirs here.>

## Plan in brief
- <phases and what decides the next one; the item queue is in PLAN.md>

## Lessons from earlier runs
- <lessons copied by root from earlier runs' FINAL_SUMMARY.md and COORDINATOR.md, one or two lines each>

## Lessons from this run
- <orchestrator N: one or two lines per lesson. If a lesson corrects results/WORKFLOW.md, fix it there too.>

## State
Rewrite this section at every handoff. Fill in every field, writing "none" where nothing applies.
- Written: <date time from `date`> by orchestrator <N>
- Running: <item id, job or process id, where its output goes, expected end> for each running item
- Subagents still running: <item id, role, the report file it will write>
- Waiting for review: <item id, report file, worktree>
- Partial results: <item id, what exists so far, path>
- Pending: <next items in PLAN.md order>
- Blocked: <item id, reason>
- For the user: <sessions to stop, refused actions with the exact command, anything only they can do>
- Stop condition: <last stop-check line from LOG.md>
- Open questions: <decisions deferred, and what would settle them>
- Next step: <what the next orchestrator does first, and why>
