#!/bin/bash
# Append one timestamped line to LOG.md, with the time taken from the clock.
#   <run_dir>/tools/log.sh "O3: #152 done: PR #203, checks rc 0"
# Agents use it instead of echo, because times they typed themselves ran up to an hour ahead of the clock.
source "$(dirname "$0")/common.sh"
[[ $# -gt 0 ]] || { echo "usage: $0 <text>" >&2; exit 2; }
log "$*"
tail -1 "$LOG"
