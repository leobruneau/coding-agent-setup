#!/bin/bash
# Stop the run's background work: kill each process group listed in tools/work.pids, run CANCEL_CMD from
# run.env if set, then log "run stopped". Safe to run more than once.
source "$(dirname "$0")/common.sh"
if [[ -f $TOOLS/work.pids ]]; then
  while read -r pid _; do
    [[ $pid =~ ^[0-9]+$ ]] || continue
    if kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null; then
      log "stop_work: stopped pid $pid"
    fi
  done < "$TOOLS/work.pids"
fi
if [[ -n ${CANCEL_CMD:-} ]]; then
  bash -c "$CANCEL_CMD"
  rc=$?
  log "stop_work: ran '$CANCEL_CMD' (exit $rc)"
fi
log "run stopped"
