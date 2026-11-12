#!/usr/bin/env bash
# Copy local Claude Code changes from ~/.claude back into claude/, then list what changed.
#
# - Rewrites claude/settings.json from ~/.claude/settings.json, with $HOME replaced by {{HOME}}.
# - Copies CLAUDE.md, skills and mods that are plain files in ~/.claude (not symlinks into this repo).
#   Run ./install.sh afterwards to replace them with symlinks.
# - Skips ~/.claude/skills/synced, which claude.ai manages.
#
# Review with `git diff`, then commit and push.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/claude"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

jq --arg h "$HOME" 'walk(if type == "string" then gsub($h; "{{HOME}}") else . end)' \
  "$dest/settings.json" > "$src/settings.json"
echo "copied  settings.json"

if [[ -f "$dest/CLAUDE.md" && ! -L "$dest/CLAUDE.md" ]]; then
  cp "$dest/CLAUDE.md" "$src/CLAUDE.md"
  echo "copied  CLAUDE.md"
fi

for kind in skills mods; do
  for d in "$dest/$kind"/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"; name="$(basename "$d")"
    [[ -L "$d" || "$kind/$name" == "skills/synced" ]] && continue
    rsync -a --exclude '.DS_Store' --exclude 'types/claude-code*' "$d/" "$src/$kind/$name/"
    echo "copied  $kind/$name"
  done
done

git -C "$repo" status --short
