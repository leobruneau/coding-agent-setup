#!/usr/bin/env python3
"""Extract a compact digest of Claude Code work from stored history.

Claude Code stores one JSONL transcript per session under
~/.claude/projects/<encoded-cwd>/<session>.jsonl. Each line is a JSON object
with a timestamp, the working directory (cwd), the git branch, and a message
(user prompt, assistant text/thinking, or tool use).

This script reads those transcripts, filters by time window and optionally by
project, and prints a readable digest: per project, per session, what the user
asked for, what Claude did (files touched, commands run, tools used), and a
trim of the assistant's own summaries. The point is to hand the model the raw
material for a report without making it parse JSONL itself.

Usage:
  extract.py --list                       # list projects + date ranges, then exit
  extract.py --since 2026-06-01            # all projects since a date
  extract.py --days 7                      # all projects, last N days
  extract.py --since 2026-06-01 --project harmonic-tension
  extract.py --since 2026-06-01 --until 2026-06-15 --project foo --project bar

Time bounds are inclusive dates (YYYY-MM-DD), compared in UTC. --project
matches if the substring appears in the project's cwd (repeatable).
"""
import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
MAX_TEXT = 400  # truncate any single text block to keep the digest compact
MUTATING = {"Edit", "Write", "NotebookEdit", "MultiEdit"}


def parse_ts(s):
    if not s:
        return None
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


def text_from_content(content):
    """User/assistant content is a string or a list of blocks. Pull plain text."""
    if isinstance(content, str):
        return content.strip()
    if not isinstance(content, list):
        return ""
    out = []
    for b in content:
        if isinstance(b, dict) and b.get("type") == "text":
            out.append(str(b.get("text", "")).strip())
    return "\n".join(t for t in out if t).strip()


def tool_summary(block):
    """(name, detail) for a tool_use block, surfacing the parameter that matters."""
    name = block.get("name", "tool")
    inp = block.get("input", {}) or {}
    for key in ("file_path", "path", "notebook_path"):
        if key in inp:
            return name, str(inp[key])
    if "command" in inp:
        return name, str(inp["command"]).replace("\n", " ")[:160]
    if "pattern" in inp:
        return name, f"/{inp['pattern']}/"
    if "description" in inp:
        return name, str(inp["description"])
    return name, ""


def clip(s, n=MAX_TEXT):
    s = " ".join(s.split())
    return s if len(s) <= n else s[:n] + " …"


def is_noise(txt):
    """Skip injected/meta user content that isn't a real human prompt."""
    if not txt:
        return True
    head = txt.lstrip()[:40].lower()
    return head.startswith((
        "<system-reminder", "<command-name", "caveat:", "<local-command",
        "<bash-input", "<bash-stdout", "<bash-stderr", "[request interrupted",
    ))


def scan_session(path, seen):
    """Read one transcript. Return dict of metadata + ordered events, or None if empty.

    `seen` is a shared set of message uuids already counted. Resumed sessions
    replay earlier messages verbatim (same uuid), so skipping seen uuids dedupes
    work that would otherwise be counted two or three times across transcripts.
    """
    cwd = None
    branches = set()
    title = None
    first_ts = last_ts = None
    events = []  # (timestamp, kind, text) where kind in {prompt, said}
    pending_tools = []  # (timestamp, tool_name, detail)

    try:
        fh = open(path, encoding="utf-8")
    except OSError:
        return None
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            u = d.get("uuid")
            if u:
                if u in seen:
                    continue
                seen.add(u)
            if d.get("cwd") and not cwd:
                cwd = d["cwd"]
            if d.get("gitBranch"):
                branches.add(d["gitBranch"])
            ts = parse_ts(d.get("timestamp"))
            if ts:
                first_ts = first_ts or ts
                last_ts = ts
            t = d.get("type")
            if t == "ai-title" and not title:
                title = d.get("title") or d.get("leafTitle")
            if d.get("isSidechain"):
                continue  # subagent chatter; the main thread already reflects the outcome
            msg = d.get("message")
            if not isinstance(msg, dict):
                continue
            role = msg.get("role")
            content = msg.get("content")
            if role == "user":
                txt = text_from_content(content)
                if not is_noise(txt):
                    events.append((ts, "prompt", clip(txt)))
            elif role == "assistant":
                said = text_from_content(content)
                if said:
                    events.append((ts, "said", clip(said)))
                if isinstance(content, list):
                    for b in content:
                        if isinstance(b, dict) and b.get("type") == "tool_use":
                            nm, detail = tool_summary(b)
                            pending_tools.append((ts, nm, detail))

    if not first_ts and not events:
        return None
    return {
        "path": str(path),
        "cwd": cwd or "(unknown)",
        "branches": sorted(branches),
        "title": title,
        "first_ts": first_ts,
        "last_ts": last_ts,
        "events": events,
        "tools": pending_tools,
    }


def overlaps(sess, since, until):
    f, l = sess["first_ts"], sess["last_ts"]
    if not f:
        return False
    if since and l and l < since:
        return False
    if until and f > until:
        return False
    return True


def in_window(ts, since, until):
    if ts is None:
        return True
    if since and ts < since:
        return False
    if until and ts > until:
        return False
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", help="inclusive start date YYYY-MM-DD")
    ap.add_argument("--until", help="inclusive end date YYYY-MM-DD")
    ap.add_argument("--days", type=int, help="window = last N days (overrides --since)")
    ap.add_argument("--project", action="append", default=[],
                    help="substring filter on project cwd (repeatable)")
    ap.add_argument("--list", action="store_true", help="list projects and exit")
    ap.add_argument("--brief", action="store_true",
                    help="compact output: drop Claude's prose summaries, collapse "
                         "actions to a touched-file list + command count. Use for "
                         "wide scans (many projects / long windows).")
    args = ap.parse_args()

    now = dt.datetime.now(dt.timezone.utc)
    if args.days:
        since = now - dt.timedelta(days=args.days)
    elif args.since:
        since = parse_ts(args.since + "T00:00:00+00:00")
    else:
        since = None
    until = parse_ts(args.until + "T23:59:59+00:00") if args.until else None

    if not PROJECTS_DIR.is_dir():
        print(f"No history found at {PROJECTS_DIR}", file=sys.stderr)
        return 1

    # Scan every session once, group by cwd. Process oldest transcript first and
    # share one `seen` set so replayed messages in resumed sessions are deduped.
    files = [p for d in PROJECTS_DIR.iterdir() if d.is_dir()
             for p in d.glob("*.jsonl")]
    files.sort(key=lambda p: p.stat().st_mtime)
    seen = set()
    by_cwd = {}
    for jsonl in files:
        sess = scan_session(jsonl, seen)
        if not sess:
            continue
        by_cwd.setdefault(sess["cwd"], []).append(sess)

    def project_matches(cwd):
        return not args.project or any(p.lower() in cwd.lower() for p in args.project)

    if args.list:
        print("# Projects in Claude Code history\n")
        for cwd in sorted(by_cwd):
            if not project_matches(cwd):
                continue
            sessions = by_cwd[cwd]
            firsts = [s["first_ts"] for s in sessions if s["first_ts"]]
            lasts = [s["last_ts"] for s in sessions if s["last_ts"]]
            lo = min(firsts).date() if firsts else "?"
            hi = max(lasts).date() if lasts else "?"
            is_git = (Path(cwd) / ".git").is_dir()
            print(f"- {cwd}")
            print(f"    sessions: {len(sessions)} | active: {lo} → {hi} | "
                  f"git repo: {'yes' if is_git else 'no'}")
        return 0

    win = []
    if since:
        win.append(f"since {since.date()}")
    if until:
        win.append(f"until {until.date()}")
    print(f"# Work digest ({', '.join(win) if win else 'all time'})\n")

    any_out = False
    for cwd in sorted(by_cwd):
        if not project_matches(cwd):
            continue
        sessions = [s for s in by_cwd[cwd] if overlaps(s, since, until)]
        if not sessions:
            continue
        any_out = True
        is_git = (Path(cwd) / ".git").is_dir()
        print(f"\n## Project: {cwd}")
        print(f"git repo: {'yes — run git log for commit-level detail' if is_git else 'no'}\n")

        sessions.sort(key=lambda s: s["first_ts"] or now)
        for s in sessions:
            ev = [(ts, k, tx) for (ts, k, tx) in s["events"] if in_window(ts, since, until)]
            if args.brief:
                ev = [e for e in ev if e[1] == "prompt"]  # keep human intent only
            tools = [(nm, detail) for (ts, nm, detail) in s["tools"]
                     if in_window(ts, since, until)]
            if not ev and not tools:
                continue
            span = ""
            if s["first_ts"]:
                span = s["first_ts"].strftime("%Y-%m-%d %H:%M")
                if s["last_ts"]:
                    span += " → " + s["last_ts"].strftime("%Y-%m-%d %H:%M")
            head = s["title"] or "(untitled session)"
            print(f"### {head}")
            print(f"_{span} | branches: {', '.join(s['branches']) or 'n/a'}_\n")
            for ts, kind, tx in ev:
                label = {"prompt": "USER", "said": "CLAUDE"}.get(kind, kind)
                print(f"- **{label}:** {tx}")
            if tools and args.brief:
                files_touched = sorted({d for nm, d in tools if nm in MUTATING and d})
                ncmd = sum(1 for nm, _ in tools if nm == "Bash")
                if files_touched:
                    print(f"- **files changed ({len(files_touched)}):** "
                          + ", ".join(files_touched))
                print(f"- **{len(tools)} actions, {ncmd} shell commands**")
            elif tools:
                print(f"- **actions ({len(tools)}):**")
                for nm, detail in tools:
                    print(f"    - {nm}: {detail}" if detail else f"    - {nm}")
            print()

    if not any_out:
        print("_No sessions matched the filters._")
    return 0


if __name__ == "__main__":
    sys.exit(main())
