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
| orchestrator root | this session, the one the user talks to | hand off below ~120K | set up, launch orchestrator 1, write ROOT_HANDOFF.md |
| orchestrator N | `claude --bg -n "<TAG> \| O<N>"` session, model opus | hand off at ~150K | plan, decide, delegate, review, log, check the stop condition |
| subagents | Agent tool, model sonnet, effort low or medium | small | one narrow task, a report file and a reply of 150 words or fewer |
| final summary | `claude --bg -n "<TAG> \| FS"` session, model opus | | review every orchestrator, write FINAL_SUMMARY.md, do the end-of-run checks |
| watchdog | `tools/watchdog.sh`, a detached shell loop | | launch a new orchestrator if LOG.md goes silent |

Orchestrators are separate background sessions, not subagents, so the user can list and open them with
`claude agents` and `claude attach <id>`. Measure context with `tools/ctx` (this skill's `scripts/ctx`),
`/context` or the token counts in the transcript. Estimate only if no such tool works. The user may set
other budgets.

When the user comes back, they open the final summary session and keep working there: they ask
questions, review and merge, deploy, clean up, and often start the next run from that same session. In
the runs so far, nobody ever woke the original root session. So the final summary session does the
end-of-run checks, and a session that was the final summary of an earlier run can be root of the next
one.

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
`launch_summary.sh` start background sessions, so the names stay consistent, and
`launch_orchestrator.sh` never gives two sessions the same number. If root is itself named after an
earlier run (`<old TAG> | FS`), suggest at step 9 that the user `/rename` it to `<TAG> | root`.

## The run directory

Each run gets its own folder named `unattended-run-<YYYY-MM-DD-HHMM>-<TAG>`, stamped with the time root
starts the setup, e.g. `unattended-run-2026-11-01-1108-amber-falcon`. The timestamp sorts runs by date,
and the tag links the folder to its sessions.

The run directory is the one place every agent goes for the mission, earlier results it can reuse and the
tools the run needs. Orchestrators read it when they start, and every subagent brief names it, so no agent
works from a retold version of the goal. It holds:

```
unattended-run-<YYYY-MM-DD-HHMM>-<TAG>/
  MISSION.md         goal, setup answers, stop condition, backstops, rules, handoff procedure (read-only)
  SUMMARIZER.md      brief for the final summary session (read-only)
  COORDINATOR.md     facts, tools, lessons and the current State
  PLAN.md            work queue with a status per item, and dated changes
  LOG.md             append-only log; the scripts read some of its lines
  ROOT_HANDOFF.md    what root set up and what is left to do at the end
  inputs/            earlier results, data and notes the run may reuse, each described in inputs/README.md
  tools/             run.env, this skill's scripts, the run's own scripts, work.pids and timer.pids
  results/           everything the run produces; WORKFLOW.md holds the per-role briefs
  repo/              in a git project, a detached worktree at the base branch (the workspace)
  worktrees/         in a git project, one worktree per item, outside repo/
  work/              the workspace, only when the project has no version control
  SUMMARY.md         written by the last orchestrator
  FINAL_SUMMARY.md   written by the final summary session
```

## Scripts

Root copies this skill's `scripts/` into `tools/`. Every script reads `tools/run.env` and logs to LOG.md.
They need bash, `claude` on the PATH, GNU or BSD `date` and `stat`, and perl on macOS for `setsid`.

| Script | What it does |
|---|---|
| `launch_orchestrator.sh <N> [recovery]` | starts orchestrator N with a prompt that gives its number and its predecessor's session id. Logs `launch orchestrator N <id>` and, unless it is a recovery launch, `handoff orchestrator <caller> -> <N>`. If N was launched before, it takes the next free number and names the caller as the predecessor. Above MAX_ORCH it stops the run and starts the final summary instead |
| `launch_summary.sh` | starts the final summary session once, stopping the background work first if nothing has, then stops the watchdog and timers in `timer.pids` other than its caller. A second call only logs a skip |
| `stop_work.sh` | kills each process group listed in `tools/work.pids`, runs CANCEL_CMD, logs `run stopped` |
| `run_at.sh "<YYYY-MM-DD HH:MM>" <command>` | runs a command at a set time outside any Claude session. Refuses a past time, logs its PID |
| `watchdog.sh` | every minute, if LOG.md has been silent for WATCHDOG_MIN minutes, launches the next orchestrator in recovery mode. When the clock jumps after the machine sleeps, it logs the wake-up, which restarts the count. Exits when the run stops |
| `start_timers.sh` | starts `watchdog.sh` and, when STOP_AT is set, the two `run_at.sh` timers, all detached. On macOS it also starts `caffeinate` for the watchdog's lifetime. Skips a watchdog that is still alive, then prints each process in `timer.pids` as alive or not running |
| `log.sh "<text>"` | appends `- <date time> <text>` to LOG.md with the time from `date`. Agents log through it |
| `sessions.sh` | lists the run's `<TAG> \| ...` sessions with their state and prints a `! claude stop <id>` line for each, for the user to paste |
| `check_tag.sh <tag> [<parent dir>]` | checks that a TAG is 2 or 3 lowercase words and not in use. Root runs it from the skill folder before the run directory exists |
| `ctx [session_id] [max_tokens]` | prints the session's context use, e.g. `29.2K / 1000K tokens (2.9%)`, from its transcript. Reads `$CLAUDE_CODE_SESSION_ID`; lags one API call |
| `setsid` | a perl stand-in for macOS, which has no setsid(1). `common.sh` puts `tools/` last on PATH, so a real setsid wins |
| `common.sh` | helpers the others source |

The scripts find their state in these LOG.md lines. Agents never write them by hand and never reword them:
`launch orchestrator N <id>`, `handoff orchestrator N -> M`, `run stopped`, `final summary launched <id>`.
The final summary session writes `final summary written`.

`start_timers.sh` starts the detached scripts. To start one by hand, use
`nohup setsid <script> ... >/dev/null 2>&1 </dev/null &` with absolute paths (`tools/setsid` on macOS).

### Placeholders

The templates use `<...>` placeholders. These need a choice:

| Placeholder | Where | How to choose |
|---|---|---|
| RUN_NAME | run.env, templates | short name of the task plus the date |
| TAG | run.env, MISSION.md, SUMMARIZER.md | 2 or 3 words naming the task, checked with `check_tag.sh`; see "Session names" |
| RUN_DIR, WORKSPACE | run.env, templates | absolute paths, from setup steps 3 and 5 |
| PREFIX | run.env, MISSION.md | short lowercase tag for every job and process the run starts, e.g. `ur1101_` |
| PERMISSION_MODE | run.env | the mode the user agrees to. A session that hits a permission prompt stalls, because nobody answers |
| MAX_ORCH | run.env | backstop on the number of orchestrators. See setup step 4 for sizing; default 10 |
| STOP_AT, SUMMARY_AT | run.env, MISSION.md | see "Time limits"; empty without a time component |
| WATCHDOG_MIN | run.env | default 45. Longer than the 20-minute logging interval plus the slowest single step |
| CANCEL_CMD | run.env | a command that cancels the run's jobs in a scheduler or CI by PREFIX; empty if the run starts none |
| CTX_TOOL, BUDGET | MISSION.md | the context tool found at setup; default budget 150K |
| RETRIES, NO_PROGRESS_MIN | MISSION.md | attempts before an item counts as blocked (default 2); minutes without a finished item before the run stops (default 180, longer than the slowest item) |

Take every date and time in the templates from `date '+%Y-%m-%d %H:%M'`. Root typed setup times by hand
in one run and wrote them 15 minutes ahead of the clock.

## Setup (root)

1. Ask the user, in one message. If an earlier `unattended-run-*` folder exists for the same project,
   read its MISSION.md first and offer its answers as defaults, so the user only answers what differs.
   In two runs in a row the user accepted the same run directory, outside actions, permission mode and
   limits "as proposed".
   - Where to put the run directory. Suggest the folder next to the earlier runs, or the project root,
     and say whether version control ignores that path.
   - The stop condition. It can be a time ("by 08:00"), a completion criterion ("every open issue in the
     tracker is resolved or marked blocked", "the test suite passes", "the metric reaches X"), a budget,
     or a combination ("whichever comes first"). If it names a tracker, ask where the tracker lives (a
     folder of markdown files, a GitHub repo, another system) unless the project makes it obvious. If it
     names a budget, ask what it measures: hours, orchestrator count, jobs or money.
   - A backstop, if the stop condition has no time component: a latest end time, a maximum number of
     orchestrators, or both. A completion rule that can't be met would otherwise keep the run going.
   - Which outside actions the run may take: commits, pushes, pull requests, closing or commenting on
     issues, messages, spending money. Suggest "none beyond files in the workspace and the run directory".
   - How the result should arrive, when the run produces many changes: one change per item, a combined
     branch or pull request for a single review and deploy, or both. In two runs in a row the user wanted
     one combined pull request to review and deploy. The run that didn't make one left the final summary
     session to build it the next morning.
   - Scope questions the task raises: items to skip, items too big for the run (split them, or do a
     first slice), how deep the per-item workflow goes for small items.
   - The permission mode for the background sessions.
   - The goal, if the request leaves it unclear.

   Wait for the answers. Start nothing before the user replies. The user may add requests while you
   work, such as a cleanup before the start or new issues to include. Treat each one as a setup answer:
   quote it in MISSION.md and show it at step 7.
2. Read the project's instructions (CLAUDE.md, AGENTS.md, README), the user's global instructions and any
   handoff notes the user points to. Copy every constraint that affects the work into MISSION.md word for
   word, including the global ones, because a background session may not load them. Standing decisions
   from earlier sessions ("never work on #69", "every push to main deploys") count. Add no constraint the
   instructions don't state.
3. Choose the workspace. In a git project, create a detached worktree at the base branch in `repo/`
   inside the run directory, so the user's checkout stays clean, and give every item its own worktree
   and branch under `worktrees/`. Use absolute paths with `git worktree add`: a relative path run from
   `repo/` put the worktree inside `repo/`. Create worktrees one at a time, because two in parallel hit
   a git config lock and left a branch without its worktree. Put that in a `tools/new_wt.sh <id> <slug>`
   script that also installs dependencies. Without version control, copy what the run will change into
   `work/` in the run directory and work there. Record the path.
   - `claude --bg` refuses a workspace that isn't trusted ("Workspace not trusted"). A folder is trusted
     when it or a parent has `"hasTrustDialogAccepted": true` in `~/.claude.json`; a project the user
     already opens in Claude usually is. If the workspace isn't trusted, put the run directory under a
     trusted project, or ask the user to run `claude` once in the workspace from their own terminal and
     accept the prompt.
   - If root itself runs inside an isolated worktree, the permission check refused git commands aimed
     at another checkout ("points git at a directory computed at runtime"). Leave the worktree first.
4. Measure what limits throughput before planning, and size the plan and MAX_ORCH to it. For work done
   by agents, CPU cores are not the limit. Orchestrator context and review time are. Numbers from two
   issue-backlog runs: a sonnet subagent finished a small issue in 2 to 5 minutes; an orchestrator
   reviewed and shipped 7 or 8 items before it reached 150K tokens, in 12 to 20 minutes; 44 issues took
   8 orchestrators and 2 hours, where the plan had assumed 8 hours. So plan about 7 items per
   orchestrator, plus one or two orchestrators for integration at the end. For jobs on machines (training,
   simulations, CI), measure one unit and the number that can run at once (cores, GPUs, scheduler queue,
   CI runners, API rate limits). Run the project's checks once on the base branch and record their time.
5. Pick TAG from the goal and check it with `scripts/check_tag.sh` from this skill's folder. Create
   the run directory with the layout above. Fill in MISSION.md, SUMMARIZER.md, COORDINATOR.md,
   PLAN.md, run.env and results/WORKFLOW.md from this skill's `templates/` folder, copy `scripts/` into
   `tools/` and make the scripts executable. Create an empty LOG.md. Make MISSION.md and SUMMARIZER.md
   read-only.
   - Write `results/WORKFLOW.md` yourself: one brief per subagent role, the outputs each writes to
     `results/`, and the policy for settling review findings without the user. In one run orchestrator 1
     wrote it, and spent its first context on that.
   - Build the run's own tools in `tools/` and smoke-test each one: a checks script that runs every gate
     the project's CI runs (tests, lint, type checks, generated-code drift) and prints one exit code per
     gate; scripts to start and stop the app for a hands-on check; a browser runner if the work has a UI.
     A CI job the local checks script skipped turned two pull requests red after they opened. Tools copied
     from an earlier run carry its paths and PREFIX; read them from `run.env` instead.
6. Fill `inputs/`. Look for earlier `unattended-run-*` folders in the parent folder of the run directory,
   and in the places the user or the project names. Link what the plan will use, and describe each item
   in `inputs/README.md`: where it came from and what it shows. Read each earlier run's FINAL_SUMMARY.md
   and COORDINATOR.md lessons, and copy the ones that still apply into COORDINATOR.md "Lessons from earlier
   runs". If nothing applies, write that in the file.
7. Show the user the whole setup in one message: run directory, TAG and the session names it gives,
   workspace, the goal as quoted, the stop condition with its check and backstops, STOP_AT and
   SUMMARY_AT, allowed outside actions, permission mode, the constraints copied and the first PLAN.md
   items. Wait for the user to confirm, and fix what they correct. Re-read the tracker or the inputs just
   before launch: in one run new issues appeared during setup.
8. Run `<RUN_DIR>/tools/start_timers.sh`. It starts the watchdog, `caffeinate` on macOS and, if STOP_AT
   is set, the STOP_AT and SUMMARY_AT timers. Check that it lists each one as alive and that LOG.md has a
   PID line for each. If `run_at.sh` refused a time, correct run.env and run `start_timers.sh` again. On a
   laptop, tell the user to keep it on power with the lid open. In one run the machine slept for an hour
   mid-run.
9. Run `tools/launch_orchestrator.sh 1`. If it fails (no `claude` command, no `--bg` support, permission
   mode rejected), stop and tell the user. Don't do the work in this session instead. Within a few
   minutes, check that orchestrator 1 has written its first LOG.md line. Tell the user the session id,
   the session name `<TAG> | O1` and the run directory path, and that the final summary session
   `<TAG> | FS` is the one to open when they come back.
10. Write ROOT_HANDOFF.md: what you set up, the PIDs, anything you left on purpose (your own worktree,
    branches), and the steps in "At the end". Then end your turn without polling.

## Time limits

If the user gives a time limit, set STOP_AT to that limit minus about 30 minutes and SUMMARY_AT to STOP_AT
plus 15 minutes, so the final summary is done by the limit. Orchestrators start no work that can't finish
before STOP_AT. From 30 minutes before STOP_AT, they don't hand off. They write SUMMARY.md themselves.
If the run ends with an integration item, give it a latest start time in PLAN.md, so the clock can't
leave a pile of unintegrated branches.

## Stop condition and backstops

- An orchestrator checks the stop condition when it starts, after each unit of work finishes, and at
  least every 20 minutes. Each check is a LOG.md line `stop-check: met|not met|unknown, <evidence>`.
  These lines also tell the watchdog the orchestrator is alive. A script that compares the tracker with
  the open changes makes the check cheap and repeatable.
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
- When the run produces many branches, make the stop condition include the integration proof (see
  "Parallel branches"), so "every item has a change" doesn't count as done while the changes conflict.

## Documents

Agents pass information to each other only through the files in the run directory, never by retelling it.
Retelling drifts from what the user asked.

- `MISSION.md` (read-only) quotes the user's goal, ideas, setup answers, constraints and allowed outside
  actions word for word, says what each answer accepts from root's proposal, and gives the stop
  condition, backstops, hard rules, recovery steps and handoff procedure. It wins over every other file.
  No agent may change the goal, the stop condition or a backstop. Only root edits MISSION.md, only to fix
  a factual error, and logs the fix in LOG.md.
- `SUMMARIZER.md` (read-only) is the final summary session's brief.
- `COORDINATOR.md` holds facts, tools and lessons that change during the run, and a State section. Each
  orchestrator rewrites State at handoff with every field the template lists.
- `PLAN.md` holds the work queue: one row per item with id, description, dependencies, status (`todo`,
  `running`, `review`, `done`, `blocked`), attempts (failed attempts only) and a note (result or blocking
  reason). `review` means the subagent finished and the orchestrator hasn't reviewed the work yet.
  Reordering goes in a dated "Changes" section with the reason. A small `tools/plan_set.py <id> <status>
  [attempts] [note]` that edits one row saves reading and rewriting the table.
- `results/WORKFLOW.md` holds the subagent role briefs. When a lesson shows a brief is wrong, fix the
  brief as well as noting the lesson. In one run COORDINATOR.md recorded that a file list in a brief was
  wrong, and the brief stayed wrong for the rest of the run.
- `LOG.md` is append-only, one timestamped line per decision, result, launch, handoff, stop check and
  failure. Agents write it with `tools/log.sh`. Orchestrators that typed their own times wrote lines up
  to an hour ahead of the clock.
- `inputs/README.md` lists the reusable material. An agent that reuses an input names it in LOG.md.
- `SUMMARY.md` comes from the last orchestrator and `FINAL_SUMMARY.md` from the final summary session.

## Orchestrator rules (MISSION.md repeats them)

Start and context:
- On start, your launch prompt gives your number and your predecessor's session id. If it doesn't, take
  them from the last `launch orchestrator` line in LOG.md. Read MISSION.md, COORDINATOR.md, PLAN.md and
  results/WORKFLOW.md with the Read tool, one file per call, and only the last 60 lines of LOG.md. One
  `cat` of every file overflowed the tool output and the orchestrator read everything twice. In one run
  the startup reading alone took 69K tokens, so keep the documents short. Run `tools/ctx` once to get your baseline.
- Measure context with `tools/ctx` after each unit of work and put the number in your stop-check line.
  If it fails or prints 0.0K, it is broken. Estimate and hand off early. An orchestrator that handed off on
  a guess reached 223K against a budget of 150K.
- The largest context costs are subagent replies, diffs and screenshots. Ask subagents to write their
  report to a file and reply with a few lines that name the file. Read a diff with `git diff --stat`
  first, then the files that carry risk.

Recovery:
- If LOG.md has a `handoff orchestrator <P> -> <N>` line, where P is the predecessor your prompt names, leave
  it alone. It may show as working for a while: it is finishing its last turn and answering subagents
  that report late.
- If your prompt says recovery, or LOG.md has no handoff line for you, your predecessor crashed or
  stalled. First check whether it is still working: if LOG.md has lines from it written after your launch
  line, it is alive. Log `recovery not needed, orchestrator <P> is active` and end your turn. In one run
  the machine slept, the watchdog started a recovery orchestrator, and the predecessor woke up and went
  on working.
- Otherwise rebuild State from LOG.md, PLAN.md, `results/`, `tools/work.pids`, the worktrees and the
  scheduler's job list. Set items marked `running` whose work is gone back to `todo`, adding one attempt.
  Log `recovered: <what you found>`. Don't try to stop the predecessor; list its session id in
  COORDINATOR.md State for the user.

Work:
- Pick the first `todo` item in PLAN.md whose dependencies are `done`. Before you start it, check
  `inputs/` and `results/` for an answer that already exists. Items may run in parallel, up to the
  number MISSION.md sets.
- Delegate the building: code changes, searches, log reading, analysis and debugging go to sonnet
  subagents. Keep the judging: read every diff yourself against how the user will use the change, not
  only the test results. In one run this review caught four changes that passed every test but would
  have locked the user out, deleted data or broken a button. Small fixes of a few lines you may make
  yourself.
- Each subagent brief gives the run directory path, the role brief in results/WORKFLOW.md, the scope,
  the files to read, what is ruled out, the report file to write and a reply limit. Subagents write
  their report and any draft text to files in `results/`, because you may hand off before they finish.
  Subagents don't commit, push or write to outside systems; the orchestrator does that after review.
- A subagent that changes code runs the project's tests the way the project's instructions say.
- For changes users see, run the app (a local server, a simulator, a dry run) and look at the result.
  In both runs these checks found bugs the unit tests missed: an effect loop that froze the app, and chat
  replies that were never saved.
- Give every background job or process a name starting with PREFIX. Start a local process with `setsid`
  (`tools/setsid` on macOS) and append `<pid> <item id>` to `tools/work.pids`. For scheduler or CI jobs,
  log the job id.
- Keep helper scripts in `tools/` and list them in COORDINATOR.md, never in a session's temp folder. One
  run rebuilt the same checks script in three orchestrators because each kept it in its own temp folder.
  Write scripts with absolute paths: a relative path after `cd` opened a pull request with an empty body.
- When a unit of work fails, log the error, add an attempt in PLAN.md and retry if attempts are below
  RETRIES. Otherwise mark the item blocked. A subagent that doesn't report within its expected time is a
  failure. Retry a network command that timed out once before counting it as a failure.
- Never wait more than 20 minutes without a LOG.md line. Wait in the background with a timeout (a
  `until <file exists or check passes>; do sleep 30; done` loop, or the Monitor tool), then log a stop
  check.
- Log every decision with its reason and every result with its numbers.

Permission refusals:
- In `auto` mode the permission check may refuse a command. Log the refusal with the command and the
  reason it gave. Don't retry the same action in another form, such as a script, a split command or a
  different tool. List it in SUMMARY.md as a step for the user, with the exact command. Refusals seen so
  far: `claude stop` on another session ("Interfere With Workloads"), `gh pr close` (allowed once, then
  refused), `git commit --amend` and force-push, and a `sed` or heredoc whose text contained `$(...)` or
  `rm`, refused as a deletion. Plan the run so it doesn't depend on these.
- The permission check also refuses commands it can't verify: `cd` into another repo, loops and git in
  one call, deletions with a computed path. Split them into plain commands with explicit names, or edit
  files with the Edit tool. Edit and Write need a Read of the file in the same session first.

Handoff:
- Hand off at the context budget:
  1. Cancel your own wait loops, timers and monitors, so they don't wake you after the handoff.
  2. Rewrite the State section of COORDINATOR.md, filling in every field. List each subagent still
     running with its item and the report file it will write.
  3. Append a summary of your work and results to LOG.md.
  4. Run `tools/launch_orchestrator.sh <N+1>`. It logs the launch and the handoff line. If the launch
     fails twice, log it and stop; the watchdog launches the next orchestrator.
  5. Stop working. Subagents still running will report to you. Answer each with one LOG.md line that
     names its report file, and nothing else. The next orchestrator reviews their work from the files.

Experiments:
- Screen many options cheaply, then confirm the leaders against a control on fresh repetitions. Label
  screening statistics as uncorrected.

## Parallel branches

A run that makes one branch per item ends with many branches that conflict with each other. In one run,
48 open pull requests had 99 conflicting pairs, and 48 of those came from every branch appending to the
same line of one file.

- Prevent overlap early. Record the files each item touches in its PLAN.md note. Every few items, scan
  the open branches for conflicting pairs (`git merge-tree` on each pair, as a script in `tools/`). When
  many branches touch one spot, such as a list of test modules, change that spot once so new entries
  don't collide (a glob or a loop instead of a list, new tests in new files), and tell the subagents in
  their brief.
- Integrate at the end, as the last PLAN.md items:
  1. Scan all open branches for conflicting pairs and group them into connected sets.
  2. Remove hotspots with the same edit committed to every branch that touches them. Identical edits
     merge cleanly.
  3. Make small "cuts": move a branch's new code or tests to a new file so it no longer collides.
  4. Group only what still conflicts into one branch per topic, resolving the conflicts with notes per
     resolution. Keep each group to one topic.
  5. Prove the final set: merge every final branch, in the planned order, into a local scratch branch and
     run the full checks, code generation and an app check on it. In one run this found two breaks that
     merged without a textual conflict.
  6. Review the combined branch with fresh subagents that didn't write the code, one per area, with a
     list of what to look for: data loss, behaviour in the first minutes after deploy (schedules, new
     automation, bots or workflows, new required settings), races, and regressions in existing flows. In
     both runs, a review like this, done the next morning at the user's request, found 3 to 7 real
     defects that every per-item check had passed.
  7. If the user asked for a combined branch or pull request, open it from the proven branch, with a
     deploy checklist in its body: settings and keys to add, migrations, one-off steps.
- A branch replaced by a group stays open with a "superseded by" comment, unless MISSION.md allows
  closing it and the permission check lets you. List the ones to close for the user.

## Practical lessons

- Bundle the steps of one unit of work into one job, so it waits for resources once.
- Interleave work across options, so every option has comparable coverage whenever the run stops.
- Leave shared priority resources, such as a debug queue or a shared CI runner, to their usual users.
- Run slow external commands in the background instead of blocking on them.
- Edit shared files by matching text, not line numbers, because another session may have changed them.
- Make scripts that create things on outside systems safe to run twice, e.g. by writing the created ids
  to a file and skipping what it lists. One such script crashed on a bad pattern, and because it
  records what it created, the rerun was safe.
- Plugin skills may not load in a background session with the Skill tool. Give their SKILL.md paths in
  WORKFLOW.md, so a subagent can read the file and follow it by hand. Skills that ask the user questions
  or publish to a tracker need a stated replacement: the orchestrator decides and logs, output goes to
  files.

## At the end

The final summary session follows SUMMARIZER.md. It writes FINAL_SUMMARY.md, ending with a "When you
return" section: merge order, deploy steps, side effects of merging, and paste-ready commands for what
the run could not do itself (`! claude stop <id>` from `tools/sessions.sh`, closing superseded changes,
removing worktrees). Because the user opens that session when they come back, it also answers their
questions and does the follow-up work they ask for. It works from a detached worktree, so it never holds
a branch the user wants to check out.

If the user wakes root instead, root reads ROOT_HANDOFF.md, LOG.md and FINAL_SUMMARY.md. Check that
LOG.md has `run stopped` and `final summary written`. If the stop condition is met but no summary was
launched, run `tools/launch_summary.sh` and wait for it. Run `tools/sessions.sh` and give the user its
stop lines. Check FINAL_SUMMARY.md's claims against LOG.md, and give the user the headline findings, the
run directory path and the next steps. Remove worktrees and scratch branches only after the user has
merged or said so.

## Not covered yet

- Disk space and quotas: nothing checks them. Estimate output size at setup.
- Secrets: keep keys and tokens out of the run directory, which every agent and the user read. A secret
  scanner that checks every pushed branch fails every change once one branch has a key-shaped literal, so
  tests build fake tokens at run time.
- Permission prompts: a session that hits one stalls, and the watchdog's replacement hits the same
  prompt. Pick a permission mode that covers the planned commands. See "Permission refusals" for what the
  `auto` mode check refused.
- Lid closed: `caffeinate` stops idle sleep but not sleep from closing a laptop's lid. The watchdog then
  logs the wake-up and waits, so the run loses the time but doesn't double up orchestrators.
- Non-code work has no test suite. Until a rule exists, cite a source for every claim in the results.
- Goal drift: no rule yet makes orchestrators re-read MISSION.md during long stretches between handoffs.
  With handoffs every 15 minutes, each orchestrator reads it fresh.
- Tested in real runs: launches, handoffs, the stop condition, `launch_summary.sh` stopping the timers,
  and one watchdog relaunch after the machine slept. Not yet: STOP_AT and SUMMARY_AT firing, the MAX_ORCH
  stop, CANCEL_CMD, a recovery that had to rebuild State, and the watchdog's sleep detection.
