# Plan

Approach: <how the run will reach the goal in MISSION.md, in a few sentences>.

## Queue

Orchestrators take the first `todo` item whose dependencies are `done`. Status is `todo`, `running`,
`done` or `blocked`. An item is blocked after <RETRIES> failed attempts, or when it needs a human decision,
a credential or an outside action MISSION.md doesn't allow.

| id | item | depends on | status | attempts | note (result, output path or blocking reason) |
|---|---|---|---|---|---|
| 1 | <unit of work> | | todo | 0 | |

## Changes

- <date time> orchestrator <N>: <what changed in the queue or approach> because <reason>.
