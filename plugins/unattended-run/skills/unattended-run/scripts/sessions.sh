#!/bin/bash
# List this run's Claude sessions ("<TAG> | ...") with their state, then print a `claude stop` line for
# each one still listed, for the user to paste. In auto mode the permission classifier refused
# `claude stop` from inside a run every time, so stopping sessions is the user's step.
#   <run_dir>/tools/sessions.sh
source "$(dirname "$0")/common.sh"
claude agents --json </dev/null 2>/dev/null | awk -v tag="$TAG | " '
  /"id":/    { id = $0;    sub(/^ *"id": *"/, "", id);       sub(/".*/, "", id) }
  /"name":/  { name = $0;  sub(/^ *"name": *"/, "", name);   sub(/",? *$/, "", name) }
  /"state":/ { state = $0; sub(/^ *"state": *"/, "", state); sub(/".*/, "", state) }
  /^ *}/     { if (index(name, tag) == 1) { print id "\t" name "\t" state; ids = ids " " id }
               id = name = state = "" }
  END        { if (ids == "") print "no " tag "sessions listed"
               else { n = split(ids, a, " "); for (i = 1; i <= n; i++) print "! claude stop " a[i] } }'
