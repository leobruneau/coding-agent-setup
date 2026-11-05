#!/bin/bash
# Run a command at a set time, outside any Claude session, and log it in LOG.md.
#   nohup setsid <run_dir>/tools/run_at.sh "YYYY-MM-DD HH:MM" <absolute command path> [args...] \
#     >/dev/null 2>&1 </dev/null &
# Refuses a time in the past. Checks the clock every minute, so on a machine that sleeps the command runs
# when it wakes.
source "$(dirname "$0")/common.sh"
WHEN=$1; shift
t=$(to_epoch "$WHEN") || { log "run_at: cannot read time '$WHEN', not scheduling '$*'"; exit 1; }
if (( t <= $(date +%s) )); then
  log "run_at: '$WHEN' has passed, not scheduling '$*'"
  exit 1
fi
echo "$$ run_at $WHEN $*" >> "$TOOLS/timer.pids"
log "run_at: pid $$ will run '$*' at $WHEN"
while (( $(date +%s) < t )); do sleep 60; done
"$@"
rc=$?
log "run_at: ran '$*' (exit $rc)"
