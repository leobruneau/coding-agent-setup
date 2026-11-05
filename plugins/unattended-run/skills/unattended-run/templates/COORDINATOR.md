# Coordinator notes (orchestrators update this)

Read MISSION.md first. It holds the goal, the stop condition, the rules and the handoff procedure, and it
wins over this file. This file holds facts and tools that change during the run, and the current State.

## Facts
- <what limits throughput, time per unit of work, slow commands and how to run them>

## Tools in the run directory
- `tools/launch_orchestrator.sh <N> [recovery]`, `tools/launch_summary.sh`, `tools/stop_work.sh`,
  `tools/run_at.sh`, `tools/watchdog.sh`: see the skill's SKILL.md, "Scripts".
- <the run's own scripts: what each does, arguments, outputs>

## Plan in brief
- <phases and what decides the next one; the item queue is in PLAN.md>

## State
Rewrite this section at every handoff. Fill in every field, writing "none" where nothing applies.
- Written: <date time> by orchestrator <N>
- Running: <item id, job or process id, where its output goes, expected end> for each running item
- Partial results: <item id, what exists so far, path>
- Pending: <next items in PLAN.md order>
- Blocked: <item id, reason>
- Stop condition: <last stop-check line from LOG.md>
- Open questions: <decisions deferred, and what would settle them>
- Next step: <what the next orchestrator does first, and why>
