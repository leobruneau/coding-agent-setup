#!/bin/bash
# Launch the next orchestrator in recovery mode when LOG.md has been silent for WATCHDOG_MIN minutes.
# After the machine sleeps, it logs the wake-up, which restarts the silence count, so a sleeping
# laptop doesn't look like a stalled orchestrator. Exits once the run has stopped or the final summary
# has started.
#   nohup setsid <run_dir>/tools/watchdog.sh >/dev/null 2>&1 </dev/null &
source "$(dirname "$0")/common.sh"
echo "$$ watchdog" >> "$TOOLS/timer.pids"
log "watchdog: pid $$, relaunches after $WATCHDOG_MIN silent minutes"
prev=$(date +%s)
while sleep 60; do
  if [[ -d $RUN_DIR/.summary_started ]] || grep -q " run stopped$" "$LOG"; then
    log "watchdog: run over, exiting"
    exit 0
  fi
  now=$(date +%s)
  if (( now - prev > 300 )); then
    log "watchdog: clock jumped $(( (now - prev) / 60 )) min (machine asleep?), waiting $WATCHDOG_MIN min before judging silence"
  fi
  prev=$now
  age=$(( (now - $(mtime "$LOG")) / 60 ))
  (( age < WATCHDOG_MIN )) && continue
  last=$(grep -oE "launch orchestrator [0-9]+ " "$LOG" | awk '{print $3}' | sort -n | tail -1)
  log "watchdog: LOG.md silent for $age min, last orchestrator ${last:-none}, launching the next"
  "$TOOLS/launch_orchestrator.sh" $(( ${last:-0} + 1 )) recovery >/dev/null || log "watchdog: relaunch failed"
done
