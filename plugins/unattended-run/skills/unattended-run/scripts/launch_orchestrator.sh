#!/bin/bash
# Launch orchestrator N, log "launch orchestrator N <id>" and print the session id.
#   <run_dir>/tools/launch_orchestrator.sh <N> [recovery]
# Above MAX_ORCH it stops the run and starts the final summary instead.
source "$(dirname "$0")/common.sh"
N=$1; MODE=${2:-}
[[ $N =~ ^[0-9]+$ ]] || { echo "usage: $0 <N> [recovery]" >&2; exit 2; }
if (( N > MAX_ORCH )); then
  log "orchestrator limit $MAX_ORCH reached, stopping the run"
  "$TOOLS/stop_work.sh"
  exec "$TOOLS/launch_summary.sh"
fi
prev=$(grep -oE "launch orchestrator $((N - 1)) [0-9a-f]{8}" "$LOG" 2>/dev/null | tail -1 | awk '{print $4}')
prompt="You are orchestrator $N of $RUN_NAME. Your predecessor is orchestrator $((N - 1)), session ${prev:-none}."
prompt+=" Read $RUN_DIR/MISSION.md first and follow it, then COORDINATOR.md, PLAN.md and LOG.md in the same directory."
if [[ $MODE == recovery ]]; then
  prompt+=" The watchdog started you because LOG.md was silent for $WATCHDOG_MIN minutes. Follow the recovery steps in MISSION.md."
fi
id=$(bg_launch "$TAG | O$N" "$prompt") || exit 1
if [[ -z $id ]]; then
  log "launch orchestrator $N: no session id in the output of claude --bg"
  exit 1
fi
log "launch orchestrator $N $id${MODE:+ ($MODE)}"
echo "$id"
