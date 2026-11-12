#!/bin/bash
# Check a run tag before setup uses it. Root runs it from the skill's scripts folder, before the run
# directory exists.
#   check_tag.sh <tag> [<parent dir of the run directories>]
# Exit 0: the tag is 2 or 3 lowercase words joined by hyphens, and no open Claude session name
# ("<tag> | ...") or existing unattended-run-*-<tag> folder uses it. Exit 1: taken. Exit 2: bad format.
tag=$1; parent=${2:-.}
if [[ ! $tag =~ ^[a-z0-9]+(-[a-z0-9]+){1,2}$ ]]; then
  echo "check_tag.sh: '$tag' is not 2 or 3 lowercase words joined by hyphens" >&2
  exit 2
fi
used=$(mktemp) || exit 1
trap 'rm -f "$used"' EXIT
# Tags of open sessions: the part of each "name" before " | ".
claude agents --json </dev/null 2>/dev/null \
  | sed -n 's/^ *"name": *"\(.*\)",\{0,1\}$/\1/p' | sed 's/ | .*//' >>"$used"
# Tags of earlier run folders: unattended-run-YYYY-MM-DD-HHMM[SS]-<tag>.
# A glob, not find -printf: BSD find on macOS has no -printf, and the error went to /dev/null.
for d in "$parent"/unattended-run-*; do
  [[ -d $d ]] && basename "$d"
done | sed -E 's/^unattended-run-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4,6}-//' >>"$used"
if grep -qxF -- "$tag" "$used"; then
  echo "check_tag.sh: '$tag' is already used by an open session or a run folder in $parent" >&2
  exit 1
fi
echo "$tag"
