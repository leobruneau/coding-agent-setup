---
name: unattended-run
description: Run a long task unattended (experiment search, issue backlog, refactor, sweep, literature review) through a chain of orchestrator sessions with a fixed mission file, a stop condition with backstops, context-based handoffs, a watchdog and a final summary session.
disable-model-invocation: true
---

# Unattended run

You are "orchestrator root". You set up the run with the user, then hand the work to background
orchestrator sessions. When the stop condition is met, a final summary session reviews everything. The
user reads the result later, so everything that matters goes into files in the run directory, not into
chat.

## Roles

| Role | What it is | Default context budget | Job |
|---|---|---|---|
| orchestrator root | this session, the one the user talks to | hand off below ~120K | set up, launch orchestrator 1, report the final summary |
| orchestrator N | `claude --bg -n "<TAG> \| O<N>"` session, model opus | hand off at ~150K | plan, decide, delegate, log, check the stop condition |
| subagents | Agent tool, model sonnet, effort low or medium | small | one narrow task, report of 150 words or fewer |
| final summary | `claude --bg -n "<TAG> \| FS"` session, model opus | | review every orchestrator, write FINAL_SUMMARY.md |
| watchdog | `tools/watchdog.sh`, a detached shell loop | | launch a new orchestrator if LOG.md goes silent |

Orchestrators are separate background sessions, not subagents, so the user can list and open them with
`claude agents` and `claude attach <id>`. Root keeps a lower budget because it still has to write the final
report. Measure context with the tool the environment has, such as `tools/ctx` (this skill's `scripts/ctx`), `/context` or the token
counts in the transcript. Estimate only if no such tool exists. The user may set other budgets.

## Session names

Each run has a TAG of two lowercase words joined by a hyphen that say what the run works on, e.g.
`mirror-zeroshot` for a search over mirror-symmetry regularizers or `issue-backlog` for clearing a
tracker. Use three words when two would be vague or are already taken, e.g. `mirror-zeroshot-confirm`.
Every background session of the run is named `<TAG> | <role id>`:

| Role id | Session |
|---|---|
| `O1`, `O2`, ... | orchestrator N, including one the watchdog starts in recovery |
| `FS` | final summary |

The user can then pick out one run's sessions in `claude agents`, and two runs started at the same time
never share a session name. Root picks TAG from the goal, then runs
`scripts/check_tag.sh <TAG> <parent of the run directory>`. It exits 0 when the tag is well formed and
free, 1 when an open session or an earlier run folder already uses it, and 2 when the format is wrong.
If the tag is taken, add or change a word and check again. Root sets TAG once, writes it into
`tools/run.env` and shows it to the user at step 7. From then on TAG never changes: every orchestrator,
recovery orchestrator and the final summary of the run share it. Only `launch_orchestrator.sh` and
`launch_summary.sh` start background sessions, so the names stay consistent. Root runs in the user's own
session and has no role id.

## The run directory

Each run gets its own folder named `unattended-run-<YYYY-MM-DD-HHMM>-<TAG>`, stamped with the time root
starts the setup, e.g. `unattended-run-2026-11-01-1108-amber-falcon`. The timestamp sorts runs by date,
and the tag links the folder to its sessions.

The run directory is the one place every agent goes for the mission, earlier results it can reuse and the
tools the run needs. Orchestrators read it when they start, and every subagent brief names it, so no agent
works from a retold version of the goal. It holds:

```
unattended-run-<YYYY-MM-DD-HHMM>-<TAG>/
  MISSION.md         goal, stop condition, backstops, rules, handoff procedure (read-only)
  SUMMARIZER.md      brief for the final summary session (read-only)
  COORDINATOR.md     facts, tools and the current State
  PLAN.md            work queue with a status per item, and dated changes
  LOG.md             append-only log; the scripts read some of its lines
  ROOT_HANDOFF.md    what root set up and what it does at the end
  inputs/            earlier results, data and notes the run may reuse, each described in inputs/README.md
  tools/             run.env, this skill's scripts, the run's own scripts, work.pids and timer.pids
  results/           everything the run produces
  work/              the workspace, only when the project has no version control
  SUMMARY.md         written by the last orchestrator
  FINAL_SUMMARY.md   written by the final summary session
```

## Scripts

Root copies this skill's `scripts/` into `tools/`. Every script reads `tools/run.env` and logs to LOG.md.
They need bash, `claude` on the PATH, and GNU or BSD `date` and `stat`.

| Script | What it does |
|---|---|
| `launch_orchestrator.sh <N> [recovery]` | starts orchestrator N with a prompt that gives its number and its predecessor's session id, logs `launch orchestrator N <id>`. Above MAX_ORCH it stops the run and starts the final summary instead |
| `launch_summary.sh` | starts the final summary session once, stopping the background work first if nothing has, then stops the watchdog and timers in `timer.pids` other than its caller. A second call only logs a skip |
| `stop_work.sh` | kills each process group listed in `tools/work.pids`, runs CANCEL_CMD, logs `run stopped` |
| `run_at.sh "<YYYY-MM-DD HH:MM>" <command>` | runs a command at a set time outside any Claude session. Refuses a past time, logs its PID |
| `watchdog.sh` | every minute, if LOG.md has been silent for WATCHDOG_MIN minutes, launches the next orchestrator in recovery mode. Exits when the run stops |
| `start_timers.sh` | starts `watchdog.sh` and, when STOP_AT is set, the two `run_at.sh` timers, all detached. Skips a watchdog that is still alive, then prints each process in `timer.pids` as alive or not running |
| `check_tag.sh <tag> [<parent dir>]` | checks that a TAG is 2 or 3 lowercase words and not in use. Root runs it from the skill folder before the run directory exists |
| `ctx [session_id] [max_tokens]` | prints the session's context use, e.g. `29.2K / 1000K tokens (2.9%)`, from its transcript. Reads `$CLAUDE_CODE_SESSION_ID`; lags one API call |
| `common.sh` | helpers the others source |

The scripts find their state in these LOG.md lines. Agents never write them by hand and never reword them:
`launch orchestrator N <id>`, `run stopped`, `final summary launched <id>`. The final summary session
writes `final summary written`.

`start_timers.sh` starts the detached scripts. To start one by hand, use
`nohup setsid <script> ... >/dev/null 2>&1 </dev/null &` with absolute paths.

### Placeholders

The templates use `<...>` placeholders. These need a choice:

| Placeholder | Where | How to choose |
|---|---|---|
| RUN_NAME | run.env, templates | short name of the task plus the date |
| TAG | run.env, MISSION.md, SUMMARIZER.md | 2 or 3 words naming the task, checked with `check_tag.sh`; see "Session names" |
| RUN_DIR, WORKSPACE | run.env, templates | absolute paths, from setup steps 3 and 5 |
| PREFIX | run.env, MISSION.md | short lowercase tag for every job and process the run starts, e.g. `ur1101_` |
| PERMISSION_MODE | run.env | the mode the user agrees to. A session that hits a permission prompt stalls, because nobody answers |
| MAX_ORCH | run.env | backstop on the number of orchestrators, default 10 |
| STOP_AT, SUMMARY_AT | run.env, MISSION.md | see "Time limits"; empty without a time component |
| WATCHDOG_MIN | run.env | default 45. Longer than the 20-minute logging interval plus the slowest single step |
| CANCEL_CMD | run.env | a command that cancels the run's jobs in a scheduler or CI by PREFIX; empty if the run starts none |
| CTX_TOOL, BUDGET | MISSION.md | the context tool found at setup; default budget 150K |
| RETRIES, NO_PROGRESS_MIN | MISSION.md | attempts before an item counts as blocked (default 2); minutes without a finished item before the run stops (default 180, longer than the slowest item) |

## Setup (root)

1. Ask the user, in one message:
   - Where to put the run directory. Suggest the project root, and say whether version control ignores
     that path.
   - The stop condition. It can be a time ("by 08:00"), a completion criterion ("every open issue in the
     tracker is resolved or marked blocked", "the test suite passes", "the metric reaches X"), a budget,
     or a combination ("whichever comes first"). If it names a tracker, ask where the tracker lives (a
     folder of markdown files, a GitHub repo, another system) unless the project makes it obvious. If it
     names a budget, ask what it measures: hours, orchestrator count, jobs or money.
   - A backstop, if the stop condition has no time component: a latest end time, a maximum number of
     orchestrators, or both. A completion rule that can't be met would otherwise keep the run going.
   - Which outside actions the run may take: commits, pushes, pull requests, closing or commenting on
     issues, messages, spending money. Suggest "none beyond files in the workspace and the run directory".
   - The permission mode for the background sessions.
   - The goal, if the request leaves it unclear.

   Wait for the answers. Start nothing before the user replies.
2. Read the project's instructions (CLAUDE.md, AGENTS.md, README) and the user's global instructions. Copy
   every constraint that affects the work into MISSION.md word for word, including the global ones,
   because a background session may not load them. Add no constraint the instructions don't state.
3. Choose the workspace. In a project under version control, create a new worktree or branch, so the
   user's checkout stays clean. Without version control, copy what the run will change into `work/` in
   the run directory and work there. Record the path. `claude --bg` refuses a workspace that isn't
   trusted ("Workspace not trusted"). A folder is trusted when it or a parent has
   `"hasTrustDialogAccepted": true` in `~/.claude.json`; a project the user already opens in Claude
   usually is. If the workspace isn't trusted, put the run directory under a trusted project, or ask the
   user to run `claude` once in the workspace from their own terminal and accept the prompt.
4. Measure what limits throughput before planning: the time one unit of work takes and how many units can
   run at once (CPU cores, GPUs, scheduler queue, CI runners, API rate limits, whatever applies). Size the
   plan to the measured numbers.
5. Pick TAG from the goal and check it with `scripts/check_tag.sh` from this skill's folder. Create
   the run directory with the layout above. Fill in MISSION.md, SUMMARIZER.md, COORDINATOR.md,
   PLAN.md and run.env from this skill's `templates/` folder, copy `scripts/` into `tools/` and make the
   scripts executable. Create an empty LOG.md. Make MISSION.md and SUMMARIZER.md read-only.
6. Fill `inputs/`. Look for earlier `unattended-run-*` folders in the parent folder of the run directory,
   and in the places the user or the project names. Copy what the plan will use, link large files, and
   describe each item in `inputs/README.md`: where it came from and what it shows. If nothing applies,
   write that in the file.
7. Show the user the whole setup in one message: run directory, TAG and the session names it gives,
   workspace, the goal as quoted, the stop
   condition with its check and backstops, STOP_AT and SUMMARY_AT, allowed outside actions, permission
   mode, the constraints copied and the first PLAN.md items. Wait for the user to confirm, and fix what
   they correct.
8. Run `<RUN_DIR>/tools/start_timers.sh`. It starts the watchdog and, if STOP_AT is set, the STOP_AT and
   SUMMARY_AT timers. Check that it lists each one as alive and that LOG.md has a PID line for each. If
   `run_at.sh` refused a time, correct run.env and run `start_timers.sh` again.
9. Run `tools/launch_orchestrator.sh 1`. If it fails (no `claude` command, no `--bg` support, permission
   mode rejected), stop and tell the user. Don't do the work in this session instead. Within a few
   minutes, check that orchestrator 1 has written its first LOG.md line. Tell the user the session id,
   the session name `<TAG> | O1` and the run directory path. Suggest that they `/rename` this session to
   `<TAG> | root` so it groups with the others.
10. Write ROOT_HANDOFF.md: what you set up, the PIDs, and the steps in "At the end". Then end your turn
    without polling. The user wakes you when they come back.

## Time limits

If the user gives a time limit, set STOP_AT to that limit minus about 30 minutes and SUMMARY_AT to STOP_AT
plus 15 minutes, so the final summary is done by the limit. Orchestrators start no work that can't finish
before STOP_AT. From 30 minutes before STOP_AT, they don't hand off. They write SUMMARY.md themselves.

## Stop condition and backstops

- An orchestrator checks the stop condition when it starts, after each unit of work finishes, and at
  least every 20 minutes. Each check is a LOG.md line `stop-check: met|not met|unknown, <evidence>`.
  These lines also tell the watchdog the orchestrator is alive.
- `unknown` means the check itself failed, e.g. the tracker was unreachable. Log the error and retry at
  the next check. After 3 `unknown` checks in a row, mark the items that depend on the tracker blocked.
- An item is blocked when it failed RETRIES times, or when it needs something no agent can give: a human
  decision, a credential, or an outside action MISSION.md doesn't allow. Mark it blocked in PLAN.md with
  the reason, log it and move on. Nobody is there to answer questions, so no agent waits for one.
- Besides the stop condition, the run stops when any of these holds:
  - every PLAN.md item is done or blocked;
  - no item has finished for NO_PROGRESS_MIN minutes;
  - STOP_AT arrives (the timer runs `stop_work.sh`);
  - orchestrator MAX_ORCH would hand off (`launch_orchestrator.sh` refuses and starts the summary).
- When the run stops, the orchestrator runs `tools/stop_work.sh`, writes SUMMARY.md and runs
  `tools/launch_summary.sh`. Running either script twice is safe.

## Documents

Agents pass information to each other only through the files in the run directory, never by retelling it.
Retelling drifts from what the user asked.

- `MISSION.md` (read-only) quotes the user's goal, ideas, constraints and allowed outside actions word for
  word, and gives the stop condition, backstops, hard rules, recovery steps and handoff procedure. It wins
  over every other file. No agent may change the goal, the stop condition or a backstop. Only root edits
  MISSION.md, only to fix a factual error, and logs the fix in LOG.md.
- `SUMMARIZER.md` (read-only) is the final summary session's brief.
- `COORDINATOR.md` holds facts and tools that change during the run, and a State section. Each
  orchestrator rewrites State at handoff with every field the template lists.
- `PLAN.md` holds the work queue: one row per item with id, description, dependencies, status (`todo`,
  `running`, `done`, `blocked`), attempts (failed attempts only) and a note (result or blocking reason). Reordering goes in a
  dated "Changes" section with the reason.
- `LOG.md` is append-only, one timestamped line per decision, result, launch, handoff, stop check and
  failure. Agents take each timestamp from `date`. In the dry run, an orchestrator that typed its own
  times wrote lines ahead of the clock.
- `inputs/README.md` lists the reusable material. An agent that reuses an input names it in LOG.md.
- `SUMMARY.md` comes from the last orchestrator and `FINAL_SUMMARY.md` from the final summary session.

## Orchestrator rules (MISSION.md repeats them)

- On start, your launch prompt gives your number and your predecessor's session id. If it doesn't, take
  them from the last `launch orchestrator` line in LOG.md. Read the documents. If LOG.md has the
  `handoff orchestrator <N-1> -> <N>` line, leave your predecessor alone. `claude agents --json` can show
  it working for a while after its handoff line, and in the dry run it showed `working` even after the
  session had ended.
- Recovery. If your prompt says recovery, or LOG.md has no `handoff orchestrator <N-1> -> <N>` line, your
  predecessor crashed or stalled. If it still shows as working, `claude stop` it and log that. Rebuild State from LOG.md, PLAN.md,
  `results/`, `tools/work.pids` and the scheduler's job list. Set items marked `running` whose work is
  gone back to `todo`, adding one attempt. Log `recovered: <what you found>`.
- Pick the first `todo` item in PLAN.md whose dependencies are `done`. Before you start it, check
  `inputs/` and `results/` for an answer that already exists.
- Delegate code changes, searches, log reading, analysis and debugging to sonnet subagents. Each brief
  gives the run directory path, the scope, the files to read, what is ruled out and a report limit. Don't
  redo delegated work.
- A subagent that changes code runs the project's tests the way the project's instructions say.
- Give every background job or process a name starting with PREFIX. Start a local process with `setsid`
  and append `<pid> <item id>` to `tools/work.pids`. For scheduler or CI jobs, log the job id.
- When a unit of work fails, log the error, add an attempt in PLAN.md and retry if attempts are below
  RETRIES. Otherwise mark the item blocked. A subagent that doesn't report within its expected time is a
  failure.
- Never wait more than 20 minutes without a LOG.md line. Wait in the background with a timeout, then log
  a stop check.
- Log every decision with its reason and every result with its numbers.
- Hand off at the context budget. Rewrite State, append a work summary to LOG.md, run
  `tools/launch_orchestrator.sh <N+1>`, log `handoff orchestrator <N> -> <N+1>` and stop. If the launch
  fails twice, log it and stop; the watchdog launches the next orchestrator.
- For experiments, screen many options cheaply, then confirm the leaders against a control on fresh
  repetitions. Label screening statistics as uncorrected.

## Practical lessons

- Bundle the steps of one unit of work into one job, so it waits for resources once.
- Interleave work across options, so every option has comparable coverage whenever the run stops.
- Leave shared priority resources, such as a debug queue or a shared CI runner, to their usual users.
- Run slow external commands in the background instead of blocking on them.
- When a guard or sandbox rejects a complex shell command, put the logic in a small script in `tools/` and
  run the script.
- Edit shared files by matching text, not line numbers, because another session may have changed them.

## At the end (root)

When the user wakes you, read ROOT_HANDOFF.md and LOG.md. Check that LOG.md has `run stopped`, that no
`<TAG> | ...` session still shows as working (`claude stop` any that does, since a background session's
permission check may have blocked the summary session from doing it), that every PID in
`tools/timer.pids` is gone (`ps -p <pid>`), and that FINAL_SUMMARY.md exists with
the `final summary written` line. If the stop condition is met but no summary was launched, run
`tools/launch_summary.sh` and wait for it. Read FINAL_SUMMARY.md, check its claims against LOG.md, and give
the user the headline findings, the run directory path and the next steps.

## Not covered yet

- Disk space and quotas: nothing checks them. Estimate output size at setup.
- Secrets: keep keys and tokens out of the run directory, which every agent and the user read.
- Permission prompts: a session that hits one stalls, and the watchdog's replacement hits the same
  prompt. Pick a permission mode that covers the planned commands. In `auto` mode the permission check
  blocked the final summary session's own `kill` and `claude stop` in the dry run, while it allowed the
  scripts in `tools/`. Put cleanup in scripts, and leave the rest to root at the end.
- Non-code work has no test suite. Until a rule exists, cite a source for every claim in the results.
- Goal drift: no rule yet makes orchestrators re-read MISSION.md during long stretches between handoffs.
- Untested paths: a watchdog relaunch, recovery, the MAX_ORCH stop, timers firing and CANCEL_CMD have run
  only against a stand-in `claude`, never in a real run.
