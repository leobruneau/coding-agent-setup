#!/bin/bash
# Start the final summary session once and log "final summary launched <id>". Later calls, from a timer
# or an orchestrator, log a skip and do nothing. Stops the run's background work first if nothing has,
# and stops the watchdog and timers listed in tools/timer.pids once the summary has started.
source "$(dirname "$0")/common.sh"
if ! mkdir "$RUN_DIR/.summary_started" 2>/dev/null; then
  log "launch_summary: already started, skipping"
  exit 0
fi
grep -q " run stopped$" "$LOG" 2>/dev/null || "$TOOLS/stop_work.sh"
prompt="You are the final summary session of $RUN_NAME. Read $RUN_DIR/SUMMARIZER.md first and follow it."
if ! id=$(bg_launch "$TAG | FS" "$prompt"); then
  rmdir "$RUN_DIR/.summary_started"
  exit 1
fi
log "final summary launched ${id:-UNKNOWN}"
# Nothing is left for the watchdog or the timers to do. Stop them, except the timer that called this script.
if [[ -f $TOOLS/timer.pids ]]; then
  while read -r pid what _; do
    [[ $pid =~ ^[0-9]+$ && $pid != "$PPID" ]] || continue
    if kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null; then
      log "launch_summary: stopped $what pid $pid"
    fi
  done < "$TOOLS/timer.pids"
fi
echo "$id"
