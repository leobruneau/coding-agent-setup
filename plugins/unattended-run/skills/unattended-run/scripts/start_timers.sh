#!/bin/bash
# Start the run's detached processes: the watchdog, and the STOP_AT and SUMMARY_AT timers when run.env
# sets them. Each runs under nohup and setsid, outside any Claude session, and logs its PID in LOG.md.
#   <run_dir>/tools/start_timers.sh
# Skips the watchdog if timer.pids lists one that is still alive.
source "$(dirname "$0")/common.sh"
start() { nohup setsid "$@" >/dev/null 2>&1 </dev/null & }
alive=$(awk '$2 == "watchdog" {print $1}' "$TOOLS/timer.pids" 2>/dev/null | while read -r p; do
  kill -0 "$p" 2>/dev/null && echo "$p"; done)
if [[ -n $alive ]]; then
  echo "watchdog already running: $alive"
else
  start "$TOOLS/watchdog.sh"
fi
if [[ -n $STOP_AT ]]; then
  start "$TOOLS/run_at.sh" "$STOP_AT" "$TOOLS/stop_work.sh"
  start "$TOOLS/run_at.sh" "$SUMMARY_AT" "$TOOLS/launch_summary.sh"
fi
sleep 2
echo "processes in timer.pids:"
while read -r pid what _; do
  if kill -0 "$pid" 2>/dev/null; then echo "  $pid $what alive"; else echo "  $pid $what not running"; fi
done < "$TOOLS/timer.pids"
