#!/usr/bin/env bash
# Apply the Claude Code setup in claude/ to ~/.claude.
#
# - Symlinks CLAUDE.md, every folder in claude/skills and every folder in claude/mods into ~/.claude,
#   so edits made on this machine land in the repo.
# - Merges claude/settings.json into ~/.claude/settings.json. Keys from the repo win; keys that only
#   exist locally stay. {{HOME}} in the template becomes $HOME.
# - Moves anything it would replace to ~/.claude/backups/coding-agent-setup-<timestamp>/.
#
# Run it from a clone that stays on disk, since the symlinks point into it.
# Usage: ./install.sh [--dry-run]
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/claude"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
backup="$dest/backups/coding-agent-setup-$(date +%Y%m%d-%H%M%S)"
dry=0
[[ "${1:-}" == "--dry-run" ]] && dry=1

run() { if ((dry)); then echo "would: $*"; else "$@"; fi; }

command -v jq >/dev/null || { echo "jq is required (brew install jq, or apt install jq)" >&2; exit 1; }
run mkdir -p "$dest/skills" "$dest/mods"

link() { # link <target in repo> <path in ~/.claude>
  local target="$1" path="$2" rel="${2#"$dest"/}"
  if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then
    echo "ok      $rel"
    return
  fi
  if [[ -e "$path" || -L "$path" ]]; then
    run mkdir -p "$(dirname "$backup/$rel")"
    run mv "$path" "$backup/$rel"
    echo "backup  $rel"
  fi
  run ln -s "$target" "$path"
  echo "link    $rel"
}

link "$src/CLAUDE.md" "$dest/CLAUDE.md"
for d in "$src"/skills/*/; do d="${d%/}"; link "$d" "$dest/skills/$(basename "$d")"; done
for d in "$src"/mods/*/;   do d="${d%/}"; link "$d" "$dest/mods/$(basename "$d")"; done

rendered="$(sed "s|{{HOME}}|$HOME|g" "$src/settings.json")"
settings="$dest/settings.json"
if [[ -f "$settings" ]]; then
  merged="$(jq -s '.[0] * .[1]' "$settings" <(echo "$rendered"))"
  if [[ "$merged" == "$(jq . "$settings")" ]]; then
    echo "ok      settings.json"
  else
    run mkdir -p "$backup"
    run cp "$settings" "$backup/settings.json"
    if ((dry)); then diff <(jq . "$settings") <(echo "$merged") || true
    else echo "$merged" > "$settings"; fi
    echo "merge   settings.json"
  fi
else
  if ((dry)); then echo "would: write $settings"; else echo "$rendered" | jq . > "$settings"; fi
  echo "write   settings.json"
fi

if [[ -d "$backup" ]]; then echo "Replaced files are in $backup"; fi
echo "Restart Claude Code. Plugins listed in enabledPlugins install from their marketplaces on start."
echo "If one is missing, run: claude plugin install <name>@<marketplace>"
