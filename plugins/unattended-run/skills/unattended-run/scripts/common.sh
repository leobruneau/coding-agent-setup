#!/bin/bash
# Sourced by the other scripts. Loads run.env from the same folder and defines helpers.
TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source "$TOOLS/run.env"
LOG="$RUN_DIR/LOG.md"
# macOS has no setsid(1). tools/setsid is a perl stand-in. It goes last on PATH, so a real setsid wins.
export PATH="$PATH:$TOOLS"

# log <text>: append a timestamped line to LOG.md.
log() { echo "- $(date '+%Y-%m-%d %H:%M') $*" >> "$LOG"; }

# to_epoch "YYYY-MM-DD HH:MM": seconds since the epoch, with GNU or BSD date.
to_epoch() { date -d "$1" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M' "$1" +%s 2>/dev/null; }

# mtime <file>: modification time in seconds, with GNU or BSD stat.
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

# bg_launch <session name> <prompt>: start a background Claude session in the workspace, print its id.
bg_launch() {
  local out rc
  out=$(cd "$WORKSPACE" && claude --bg -n "$1" --model "$ORCH_MODEL" --permission-mode "$PERMISSION_MODE" "$2" 2>&1)
  rc=$?
  if (( rc != 0 )); then
    log "launch of '$1' failed (exit $rc): $(echo "$out" | tail -1)"
    return 1
  fi
  echo "$out" | grep -oE '[0-9a-f]{8}' | head -1
}
