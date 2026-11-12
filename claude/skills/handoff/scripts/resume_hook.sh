#!/usr/bin/env bash
# SessionStart hook: if a handoff is pending for this project, point the fresh
# session at it and mark it consumed (`.md.done`) so it is injected exactly once.
# Silent no-op when there is nothing pending.
#
# Why a pointer and not `cat`: Claude Code persists any hook stdout over ~10KB
# to a file and shows the model only the first 2KB. A detailed handoff clears
# 10KB routinely, so inlining it silently truncated. Read has no such cap.
# Rename first, then print, so the path we print is the one that exists.
set -uo pipefail

dir="$HOME/.claude/handoffs/${PWD//\//-}"
pending=$(ls -1 "$dir"/*.md 2>/dev/null | tail -1)
[ -n "$pending" ] || exit 0

mv -- "$pending" "$pending.done" || exit 0

printf 'A handoff was left for you by the previous session.\n'
printf 'Before doing anything else, read it IN FULL with the Read tool:\n\n'
printf '    %s.done\n\n' "$pending"
printf 'Treat it as the current task state and continue from its "Next action".\n'
