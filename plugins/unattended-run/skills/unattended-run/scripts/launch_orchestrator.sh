#!/bin/bash
# Launch orchestrator N and print its session id. Logs "launch orchestrator N <id>" and, unless this is
# a recovery launch, "handoff orchestrator <caller> -> <N>" in the same step (caller = N-1).
#   <run_dir>/tools/launch_orchestrator.sh <N> [recovery]
# If N has been launched before, it takes the next free number, so two sessions never share a name.
# Above MAX_ORCH it stops the run and starts the final summary instead.
source "$(dirname "$0")/common.sh"
N=$1; MODE=${2:-}
[[ $N =~ ^[0-9]+$ ]] || { echo "usage: $0 <N> [recovery]" >&2; exit 2; }
caller=$((N - 1))
last=$(grep -oE "launch orchestrator [0-9]+ " "$LOG" 2>/dev/null | awk '{print $3}' | sort -n | tail -1)
if [[ -n $last ]] && (( N <= last )); then
  log "launch_orchestrator: orchestrator $N was launched before, using $((last + 1))"
  N=$((last + 1))
fi
if (( N > MAX_ORCH )); then
  log "orchestrator limit $MAX_ORCH reached, stopping the run"
  "$TOOLS/stop_work.sh"
  exec "$TOOLS/launch_summary.sh"
fi
# The predecessor is the caller for a handoff, or the last one launched for a recovery.
[[ $MODE == recovery ]] && pred=$((N - 1)) || pred=$caller
prev=$(grep -oE "launch orchestrator $pred [0-9a-f]{8}" "$LOG" 2>/dev/null | tail -1 | awk '{print $4}')
prompt="You are orchestrator $N of $RUN_NAME. Your predecessor is orchestrator $pred, session ${prev:-none}."
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
# The handoff line goes in now, not when the caller gets round to it. In one run the machine slept
# between the launch and the caller's own handoff line, and the watchdog read the gap as a crash.
[[ $MODE == recovery ]] || (( caller < 1 )) || log "handoff orchestrator $caller -> $N"
echo "$id"
