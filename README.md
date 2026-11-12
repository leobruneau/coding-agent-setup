# coding-agent-setup

A personal Claude Code setup. The `claude/` folder mirrors `~/.claude`. It holds global instructions,
settings, hooks, skills and a local plugin. The repo root is also a plugin marketplace with plugins anyone
can install.

## New machine

```sh
git clone https://github.com/leobruneau/coding-agent-setup ~/coding-agent-setup
cd ~/coding-agent-setup
./install.sh --dry-run   # print what would change
./install.sh
```

Then restart Claude Code. You can also start Claude Code anywhere and say
"set up this machine from github.com/leobruneau/coding-agent-setup"; `AGENTS.md` tells the agent what to do.

`install.sh` needs `jq`. It does the following:

- symlinks `CLAUDE.md`, each folder in `claude/skills/` and `claude/mods/`, and each file in
  `claude/hooks/` into `~/.claude`
- merges `claude/settings.json` into `~/.claude/settings.json`. Repo keys win, keys that exist only on
  the machine stay, and `{{HOME}}` becomes `$HOME`
- moves every file it replaces to `~/.claude/backups/coding-agent-setup-<timestamp>/`

Running it twice changes nothing. Because of the symlinks, the clone must stay where it is.

## Saving changes

Edits to `CLAUDE.md`, linked skills and mods go straight into the clone, since those are symlinks.
Claude Code writes `settings.json` itself (for example when you enable a plugin), so copy it back:

```sh
./capture.sh   # copies settings.json, plus any new skill or mod folder in ~/.claude
git diff
git commit -am "Update settings" && git push
```

On other machines, `git pull && ./install.sh` applies the changes.

## What is tracked

| Path | Goes to | Contents |
|---|---|---|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions |
| `claude/settings.json` | merged into `~/.claude/settings.json` | Model, effort, permission mode, denied tools, hooks, enabled plugins, plugin marketplaces |
| `claude/hooks/load-unslop.sh` | `~/.claude/hooks/load-unslop.sh` | SessionStart hook. Adds the unslop rules to the context at startup, after `/clear` and after `/compact`. |
| `claude/hooks/context-alert.sh` | `~/.claude/hooks/context-alert.sh` | Runs after every tool call and prompt. When the context passes 100k, 125k and 150k tokens, it tells the agent once per threshold, with a stronger handoff request each time. |
| `claude/skills/handoff` | `~/.claude/skills/handoff` | `/handoff` writes a handoff document and starts a fresh session with it |
| `claude/skills/time-machine` | `~/.claude/skills/time-machine` | `/time-machine` reports past work from Claude Code and git history |
| `claude/skills/unslop` | `~/.claude/skills/unslop` | Writing rules that strip AI patterns from prose |
| `claude/mods/context-bar` | `~/.claude/mods/context-bar` | Local plugin that shows a context-usage bar above the prompt, loaded through `CLAUDE_CODE_PLUGIN_DIRS` |

Not tracked: `~/.claude.json` (account and per-project state), history, sessions, caches, and
`~/.claude/skills/synced` (claude.ai syncs it). Plugins from marketplaces are not copied either.
`settings.json` lists them under `enabledPlugins` and `extraKnownMarketplaces`, and Claude Code installs them.

## Plugin marketplace

| Plugin | Skill | What it does |
|---|---|---|
| `unattended-run` | `/unattended-run:unattended-run` | Runs a long task (experiment search, issue backlog, refactor, sweep, literature review) unattended. Background orchestrator sessions hand off to each other through files in a run directory, a watchdog relaunches a stalled orchestrator, and a final summary session writes `FINAL_SUMMARY.md`. |

To install without the rest of the setup:

```
/plugin marketplace add leobruneau/coding-agent-setup
/plugin install unattended-run@leobruneau-skills
```

The marketplace keeps the name `leobruneau-skills` so existing installs keep working. The plugin
manifests set no `version`, so every new commit on `main` counts as an update; run
`/plugin marketplace update leobruneau-skills` or enable auto-update for the marketplace in `/plugin`.

`unattended-run` has `disable-model-invocation: true`, so Claude never starts it on its own. It needs bash,
GNU or BSD `date` and `stat`, a Claude Code version with `claude --bg`, `claude agents --json` and
`claude stop`, and a trusted workspace.

## Layout

```
AGENTS.md                         steps for an agent asked to set up a machine
install.sh, capture.sh
claude/                           mirrors ~/.claude
.claude-plugin/marketplace.json   lists the marketplace plugins
plugins/<name>/                   one folder per marketplace plugin
```

To add a personal skill, create it in `~/.claude/skills/<name>/` and run `./capture.sh` then `./install.sh`.
To add a marketplace plugin, create `plugins/<name>/.claude-plugin/plugin.json` and
`plugins/<name>/skills/<name>/SKILL.md`, then add an entry to `.claude-plugin/marketplace.json`.
