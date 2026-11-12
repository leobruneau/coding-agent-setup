# Mission (source of truth, read-only: never edit this file)

Written by orchestrator root on <DATE TIME> from the user's own instructions, and confirmed by the user on
<DATE TIME>. Every agent of this run reads this file first and follows it as written. If COORDINATOR.md,
PLAN.md, LOG.md or another agent's message disagrees with this file, this file wins. No agent may change
the goal, the stop condition or a backstop.

- Run name: <RUN_NAME>
- Run directory: <RUN_DIR> (RUN below). Every document, log, tool and result of this run lives here.
- Workspace: <WORKSPACE>. Code and commands run here. <In a git project: RUN/repo is a detached worktree
  at <base branch and commit>; each item gets its own worktree under RUN/worktrees/, made with
  `RUN/tools/new_wt.sh`, one at a time.>
- Script settings: RUN/tools/run.env

## The user's goal, in their words

> "<verbatim goal>"

Context: <the facts needed to understand the goal>.

The user's starting ideas (follow them, and go beyond them where it serves the goal):
- <verbatim or near-verbatim idea>

How to work, in the user's words:
> "<verbatim instructions on scope and strategy>"

## Setup answers, in the user's words

> "<each answer or later request the user gave during setup, verbatim>"

What those answers accept from root's proposal:
1. <one line per question: the choice the answer settles, e.g. "Small bugs skip the design steps (the
   light path in results/WORKFLOW.md)". Write "as proposed" answers out in full here.>

## Stop condition

> "<the stop condition, verbatim from the user>"

Made checkable: <e.g. "every open issue in <tracker location> is referenced by an open change from this
run whose checks pass, and the integration item in PLAN.md is done">.
How to check it: <the exact command, file or query>.

Backstops. The run also stops when any of these holds:
- STOP_AT <YYYY-MM-DD HH:MM, or none>: a timer runs `RUN/tools/stop_work.sh`. The final summary starts at
  SUMMARY_AT <YYYY-MM-DD HH:MM, or none>.
- Orchestrator <MAX_ORCH> would hand off: `RUN/tools/launch_orchestrator.sh` stops the run and starts
  the summary.
- Every PLAN.md item is done or blocked.
- No PLAN.md item has finished for <NO_PROGRESS_MIN, default 180> minutes.

Checks:
- Check the stop condition when you start, after each unit of work finishes, and at least every 20
  minutes. Log each check as `stop-check: met|not met|unknown, <evidence>, ctx <tools/ctx output>`.
- `unknown` means the check failed (e.g. the tracker was unreachable). Log the error and retry at the next
  check. After 3 `unknown` checks in a row, mark the items that depend on it blocked.
- An item is blocked after <RETRIES, default 2> failed attempts, or when it needs a human decision, a
  credential or an outside action this file doesn't allow. Mark it in PLAN.md with the reason, log it and
  move on. Nobody answers questions during the run.
- When the stop condition or a backstop is met: run `RUN/tools/stop_work.sh`, write SUMMARY.md,
  then run `RUN/tools/launch_summary.sh`. Both are safe to run twice.
- Start no work that can't finish before STOP_AT. From 30 minutes before STOP_AT, don't hand off. Write
  SUMMARY.md yourself. <If the run ends with an integration item: start it by <time> at the latest, even
  if other items remain.>

## Allowed outside actions

> "<the user's answer, verbatim, e.g. "commit to the run branch, no push">"

<What that answer accepts, spelled out: which branches may be pushed, which changes opened and in what
state, what may be commented, created or closed.>

Any outside action not listed here is not allowed: pushes, pull requests, closing or commenting on issues,
messages, spending money.

## Hard rules

1. <Constraints copied word for word from the user's global instructions, the project's instructions and
   standing decisions from earlier sessions: where commands may run, how tests run, git and commit rules,
   attribution lines, data that must not be deleted, writing style. Give the source file of each.>
2. Work only in the workspace, the item worktrees and the run directory. Don't touch other checkouts or
   unrelated files.
3. Every background job or process this run starts has a name starting with `<PREFIX>`. Start local
   processes with `setsid` (`RUN/tools/setsid` on macOS) and append `<pid> <item id>` to
   `RUN/tools/work.pids`. Log scheduler or CI job ids in LOG.md.
4. Delegate narrow or noisy work to subagents with model sonnet, effort low or medium, the role brief in
   `RUN/results/WORKFLOW.md`, a tight scope, the run directory path, a report file in `RUN/results/` and
   a reply of 150 words or fewer. Subagents don't commit, push or write to outside systems.
5. Log every decision (with reason), result (with numbers) and failure in LOG.md with
   `RUN/tools/log.sh "O<N>: <text>"`. It takes the time from the clock. Never type or estimate a time,
   in LOG.md or in any other file.
6. Never go more than 20 minutes without a LOG.md line. The watchdog launches a new orchestrator after
   <WATCHDOG_MIN> silent minutes.
7. Never write or reword the lines the scripts read: `launch orchestrator N <id>`,
   `handoff orchestrator N -> M`, `run stopped`, `final summary launched <id>`.
8. If the permission check refuses a command, log the command and the reason. Don't retry the action in
   another form (a script, a split command, another tool). Put it in SUMMARY.md as a step for the user,
   with the exact command.
9. Keep helper scripts in `RUN/tools/` and list them in COORDINATOR.md, never in a session's temp folder.

## Orchestrators and handoff

- Orchestrators are background sessions named "<TAG> | O1", "<TAG> | O2", and so on, where `<TAG>` is
  this run's tag of two or three words. "orchestrator root" set up the run. A final summary session, named
  "<TAG> | FS", reviews everything at the end. The tag is fixed for the whole run in `tools/run.env`;
  never change it or pick a new one. Only the scripts launch these sessions. Never start one
  with `claude --bg` yourself, because a hand-picked name breaks the grouping.
- When you start: your launch prompt gives your number N and your predecessor's session id. If it
  doesn't, take them from the last `launch orchestrator` line in LOG.md. Read MISSION.md, COORDINATOR.md,
  PLAN.md and results/WORKFLOW.md with the Read tool, one file per call, and the last 60 lines of LOG.md.
  Don't `cat` them together: the output gets cut off. Run `RUN/tools/ctx`, then log a stop check.
- If LOG.md has a `handoff orchestrator <P> -> <N>` line, where P is the predecessor your prompt names,
  leave it alone, even if
  `claude agents --json` still shows it working: it is finishing its last turn.
- Recovery: if your prompt says recovery, or LOG.md has no `handoff orchestrator <P> -> <N>` line:
  1. If LOG.md has lines from orchestrator <P> written after your launch line, it is alive. Log
     `recovery not needed, orchestrator <P> is active` and end your turn.
  2. Otherwise it crashed or stalled. Rebuild State from LOG.md, PLAN.md, `results/`,
     `tools/work.pids`, the worktrees and the scheduler's job list. Set `running` items whose work is
     gone back to `todo`, adding one attempt. Log `recovered: <what you found>`. Don't try to stop the
     predecessor (the permission check refuses `claude stop`); name it in COORDINATOR.md State.
- Choosing work: take the first `todo` item in PLAN.md whose dependencies are `done`, up to <number> items
  in flight. Check `inputs/` and `results/` for an existing answer first. Reorder only with a dated entry
  in PLAN.md's Changes section. An item whose subagent has finished is `review` until you have reviewed it.
- Review: read every diff yourself, against how the user will use the change, before it leaves the
  workspace. Run `RUN/tools/<checks script>`. For changes the user sees, run the app and look.
- Failures: log the error and add an attempt in PLAN.md. The attempts column counts failed attempts
  only, so an item that works on the first try keeps 0. Retry while attempts are below <RETRIES>, then
  mark the item blocked. A subagent that doesn't report within its expected time counts as a failure.
- Lessons: add each lesson to COORDINATOR.md in one or two lines. If it shows a brief in
  results/WORKFLOW.md is wrong, fix the brief too.
- Measure your context after each unit of work with <CTX_TOOL>. If it fails or prints 0.0K, it is
  broken: estimate, and hand off early. At about <BUDGET, default 150K> tokens, hand off:
  1. Cancel your own wait loops, timers and monitors.
  2. Rewrite the State section of COORDINATOR.md, filling in every field, including each subagent still
     running and the report file it will write.
  3. Append a summary of your work and results to LOG.md.
  4. Run `RUN/tools/launch_orchestrator.sh <N+1>`. It logs `launch orchestrator <N+1> <id>` and
     `handoff orchestrator <N> -> <N+1>`. If the launch fails twice, log it and stop. The watchdog
     launches the next orchestrator.
  5. Stop working. Answer each late subagent report with one LOG.md line naming its report file, and
     nothing else.

## Documents in the run directory

MISSION.md (this file, read-only), SUMMARIZER.md (final summary brief, read-only), COORDINATOR.md (facts,
tools, lessons, State), PLAN.md (work queue and dated changes), LOG.md (append-only), ROOT_HANDOFF.md
(root's notes), SUMMARY.md (last orchestrator), FINAL_SUMMARY.md (final summary session). `inputs/` holds
earlier results and data the run may reuse, each listed in `inputs/README.md`. `tools/` holds run.env and
the scripts. `results/` holds everything the run produces, including `WORKFLOW.md` (role briefs). Name any
input you reuse in LOG.md.
