#!/usr/bin/env bash
# Register resume_hook.sh as a SessionStart hook in ~/.claude/settings.json.
# Idempotent: re-running does not duplicate the entry. Backs up settings first.
set -euo pipefail

settings="$HOME/.claude/settings.json"
hook="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resume_hook.sh"
chmod +x "$hook"

python3 - "$settings" "$hook" <<'PY'
import json, os, shutil, sys

settings, hook = sys.argv[1], sys.argv[2]
cmd = f'bash "{hook}"'

cfg = {}
if os.path.exists(settings):
    shutil.copy(settings, settings + ".bak")
    with open(settings) as f:
        cfg = json.load(f)

entries = cfg.setdefault("hooks", {}).setdefault("SessionStart", [])
if any(h.get("command") == cmd for e in entries for h in e.get("hooks", [])):
    print("already installed")
    sys.exit(0)

entries.append({
    "matcher": "startup|clear",
    "hooks": [{"type": "command", "command": cmd}],
})
with open(settings, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print(f"installed SessionStart hook in {settings}")
PY
