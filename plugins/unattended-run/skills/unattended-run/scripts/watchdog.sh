#!/bin/bash
# Launch the next orchestrator in recovery mode when LOG.md has been silent for WATCHDOG_MIN minutes.
# Exits once the run has stopped or the final summary has started.
#   nohup setsid <run_dir>/tools/watchdog.sh >/dev/null 2>&1 </dev/null &
source "$(dirname "$0")/common.sh"
echo "$$ watchdog" >> "$TOOLS/timer.pids"
log "watchdog: pid $$, relaunches after $WATCHDOG_MIN silent minutes"
while sleep 60; do
  if [[ -d $RUN_DIR/.summary_started ]] || grep -q " run stopped$" "$LOG"; then
    log "watchdog: run over, exiting"
    exit 0
  fi
  age=$(( ($(date +%s) - $(mtime "$LOG")) / 60 ))
  (( age < WATCHDOG_MIN )) && continue
  last=$(grep -oE "launch orchestrator [0-9]+" "$LOG" | tail -1 | awk '{print $3}')
  log "watchdog: LOG.md silent for $age min, last orchestrator ${last:-none}, launching the next"
  "$TOOLS/launch_orchestrator.sh" $(( ${last:-0} + 1 )) recovery >/dev/null || log "watchdog: relaunch failed"
done
