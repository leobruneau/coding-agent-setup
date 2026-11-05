# claude-skills

Claude Code skills by Léo Bruneau, packaged as a plugin marketplace.

## Plugins

| Plugin | Skill | What it does |
|---|---|---|
| `unattended-run` | `/unattended-run:unattended-run` | Runs a long task (experiment search, issue backlog, refactor, sweep, literature review) unattended. Background orchestrator sessions hand off to each other through files in a run directory, a watchdog relaunches a stalled orchestrator, and a final summary session writes `FINAL_SUMMARY.md`. |

## Install

In Claude Code:

```
/plugin marketplace add leobruneau/claude-skills
/plugin install unattended-run@leobruneau-skills
```

From a shell, `claude plugin marketplace add leobruneau/claude-skills` and
`claude plugin install unattended-run@leobruneau-skills` do the same.

The skill has `disable-model-invocation: true`, so Claude never starts it on its own. Type
`/unattended-run:unattended-run` followed by the goal.

## Update

```
/plugin marketplace update leobruneau-skills
```

The plugin manifests set no `version`, so every new commit on `main` counts as an update. To get updates
at startup without running the command, open `/plugin`, go to Marketplaces, select `leobruneau-skills`
and enable auto-update.

## Requirements

- bash, GNU or BSD `date` and `stat`
- a Claude Code version with `claude --bg`, `claude agents --json` and `claude stop`
- a trusted workspace: `claude --bg` refuses a folder whose trust prompt nobody has accepted

## Layout

```
.claude-plugin/marketplace.json              lists the plugins
plugins/unattended-run/
  .claude-plugin/plugin.json
  skills/unattended-run/
    SKILL.md
    scripts/                                 copied into each run's tools/ folder
    templates/                               MISSION.md, PLAN.md, run.env and the other run files
```

To add a skill, create `plugins/<name>/.claude-plugin/plugin.json` and `plugins/<name>/skills/<name>/SKILL.md`,
then add an entry to `.claude-plugin/marketplace.json`.
