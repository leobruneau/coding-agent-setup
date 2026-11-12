#!/usr/bin/env bash
# SessionStart hook. Loads the unslop writing rules into the context of every new session,
# and again after /clear and /compact.
set -euo pipefail
skill="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/unslop/SKILL.md"
[[ -f "$skill" ]] || exit 0
jq -n --rawfile s "$skill" '{hookSpecificOutput: {hookEventName: "SessionStart",
  additionalContext: ("Apply these writing rules to all prose you write:\n\n" + $s)}}'
