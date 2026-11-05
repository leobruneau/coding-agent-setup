# Mission (source of truth, read-only: never edit this file)

Written by orchestrator root on <DATE TIME> from the user's own instructions, and confirmed by the user on
<DATE TIME>. Every agent of this run reads this file first and follows it as written. If COORDINATOR.md,
PLAN.md, LOG.md or another agent's message disagrees with this file, this file wins. No agent may change
the goal, the stop condition or a backstop.

- Run name: <RUN_NAME>
- Run directory: <RUN_DIR>. Every document, log, tool and result of this run lives here.
- Workspace: <WORKSPACE>. Code and commands run here.
- Script settings: <RUN_DIR>/tools/run.env

## The user's goal, in their words

> "<verbatim goal>"

Context: <the facts needed to understand the goal>.

The user's starting ideas (follow them, and go beyond them where it serves the goal):
- <verbatim or near-verbatim idea>

How to work, in the user's words:
> "<verbatim instructions on scope and strategy>"

## Stop condition

> "<the stop condition, verbatim from the user>"

Made checkable: <e.g. "every open issue in <tracker location> is closed or labelled blocked with a reason">.
How to check it: <command, file or query>.

Backstops. The run also stops when any of these holds:
- STOP_AT <YYYY-MM-DD HH:MM, or none>: a timer runs `tools/stop_work.sh`. The final summary starts at
  SUMMARY_AT <YYYY-MM-DD HH:MM, or none>.
- Orchestrator <MAX_ORCH> would hand off: `tools/launch_orchestrator.sh` stops the run and starts the
  summary.
- Every PLAN.md item is done or blocked.
- No PLAN.md item has finished for <NO_PROGRESS_MIN, default 180> minutes.

Checks:
- Check the stop condition when you start, after each unit of work finishes, and at least every 20
  minutes. Log each check as `stop-check: met|not met|unknown, <evidence>`.
- `unknown` means the check failed (e.g. the tracker was unreachable). Log the error and retry at the next
  check. After 3 `unknown` checks in a row, mark the items that depend on it blocked.
- An item is blocked after <RETRIES, default 2> failed attempts, or when it needs a human decision, a
  credential or an outside action this file doesn't allow. Mark it in PLAN.md with the reason, log it and
  move on. Nobody answers questions during the run.
- When the stop condition or a backstop is met: run `<RUN_DIR>/tools/stop_work.sh`, write SUMMARY.md,
  then run `<RUN_DIR>/tools/launch_summary.sh`. Both are safe to run twice.
- Start no work that can't finish before STOP_AT. From 30 minutes before STOP_AT, don't hand off. Write
  SUMMARY.md yourself.

## Allowed outside actions

> "<the user's answer, verbatim, e.g. "commit to the run branch, no push">"

Any outside action not listed here is not allowed: pushes, pull requests, closing or commenting on issues,
messages, spending money.

## Hard rules

1. <Constraints copied word for word from the user's global instructions and the project's instructions:
   where commands may run, how tests run, git and commit rules, data that must not be deleted, writing
   style. Give the source file of each.>
2. Work only in the workspace and the run directory. Don't touch other checkouts or unrelated files.
3. Every background job or process this run starts has a name starting with `<PREFIX>`. Start local
   processes with `setsid` and append `<pid> <item id>` to `tools/work.pids`. Log scheduler or CI job ids
   in LOG.md.
4. Delegate narrow or noisy work to subagents with model sonnet, effort low or medium, a tight scope, the
   run directory path, and a report of 150 words or fewer.
5. Log every decision (with reason), result (with numbers) and failure as a timestamped line in LOG.md,
   `- YYYY-MM-DD HH:MM <text>`. Take the time from `date '+%Y-%m-%d %H:%M'` for every line; never type
   or estimate it.
6. Never go more than 20 minutes without a LOG.md line. The watchdog launches a new orchestrator after
   <WATCHDOG_MIN> silent minutes.
7. Never write or reword the lines the scripts read: `launch orchestrator N <id>`, `run stopped`,
   `final summary launched <id>`.

## Orchestrators and handoff

- Orchestrators are background sessions named "<TAG> | O1", "<TAG> | O2", and so on, where `<TAG>` is
  this run's tag of two or three words. "orchestrator root" set up the run. A final summary session, named
  "<TAG> | FS", reviews everything at the end. The tag is fixed for the whole run in `tools/run.env`;
  never change it or pick a new one. Only the scripts launch these sessions. Never start one
  with `claude --bg` yourself, because a hand-picked name breaks the grouping.
- When you start: your launch prompt gives your number N and your predecessor's session id. If it
  doesn't, take them from the last `launch orchestrator` line in LOG.md. Read COORDINATOR.md, PLAN.md and
  LOG.md. If LOG.md has the `handoff orchestrator <N-1> -> <N>` line, leave your predecessor alone, even
  if `claude agents --json` still shows it working: it is finishing its last turn. Then log a stop check.
- Recovery: if your prompt says recovery, or LOG.md has no `handoff orchestrator <N-1> -> <N>` line, your
  predecessor crashed or stalled. If `claude agents --json` still shows it working, run
  `claude stop <id>` and log it. Rebuild State from LOG.md, PLAN.md,
  `results/`, `tools/work.pids` and the scheduler's job list. Set `running` items whose work is gone back
  to `todo`, adding one attempt. Log `recovered: <what you found>`.
- Choosing work: take the first `todo` item in PLAN.md whose dependencies are `done`. Check `inputs/` and
  `results/` for an existing answer first. Reorder only with a dated entry in PLAN.md's Changes section.
- Failures: log the error and add an attempt in PLAN.md. The attempts column counts failed attempts
  only, so an item that works on the first try keeps 0. Retry while attempts are below <RETRIES>, then
  mark the item blocked. A subagent that doesn't report within its expected time counts as a failure.
- Measure your context after each unit of work with <CTX_TOOL>. At about <BUDGET, default 150K> tokens,
  hand off:
  1. Rewrite the State section of COORDINATOR.md, filling in every field.
  2. Append a summary of your work and results to LOG.md.
  3. Run `<RUN_DIR>/tools/launch_orchestrator.sh <N+1>`. It logs `launch orchestrator <N+1> <id>`.
  4. Log `handoff orchestrator <N> -> <N+1>`, then stop working. If the launch fails twice, log it and
     stop. The watchdog launches the next orchestrator.

## Documents in the run directory

MISSION.md (this file, read-only), SUMMARIZER.md (final summary brief, read-only), COORDINATOR.md (facts,
tools, State), PLAN.md (work queue and dated changes), LOG.md (append-only), ROOT_HANDOFF.md (root's
notes), SUMMARY.md (last orchestrator), FINAL_SUMMARY.md (final summary session). `inputs/` holds earlier
results and data the run may reuse, each listed in `inputs/README.md`. `tools/` holds run.env and the
scripts. `results/` holds everything the run produces. Name any input you reuse in LOG.md.
