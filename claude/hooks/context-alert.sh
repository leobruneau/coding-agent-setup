#!/usr/bin/env bash
# PostToolUse and UserPromptSubmit hook. Tells the agent when its context passes 100k, 125k and 150k
# tokens. Each threshold fires once per session. If the context shrinks (after /compact), the
# thresholds above the new size fire again when the context grows back.
set -euo pipefail

input="$(cat)"
session="$(jq -r '.session_id // empty' <<<"$input")"
transcript="$(jq -r '.transcript_path // empty' <<<"$input")"
event="$(jq -r '.hook_event_name // empty' <<<"$input")"
[[ -n "$session" && -f "$transcript" ]] || exit 0

# Context size is what the model read on the last main-thread turn plus what it wrote.
# fromjson? skips a line that Claude Code is still writing. With no usable turn, change nothing.
tokens="$(tail -n 500 "$transcript" | jq -Rn '
  [inputs | fromjson? | select(.type == "assistant" and (.isSidechain | not) and .message.usage != null)]
  | last | .message.usage // empty | (.input_tokens // 0) + (.cache_creation_input_tokens // 0)
    + (.cache_read_input_tokens // 0) + (.output_tokens // 0)' 2>/dev/null || true)"
[[ "$tokens" =~ ^[0-9]+$ ]] || exit 0

level=0
for t in 100000 125000 150000; do if ((tokens >= t)); then level=$t; fi; done

state_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/context-alert"
mkdir -p "$state_dir"
find "$state_dir" -type f -mtime +14 -delete 2>/dev/null || true
state="$state_dir/$session"
last="$(cat "$state" 2>/dev/null || echo 0)"
echo "$level" > "$state"
((level > last)) || exit 0

case $level in
  100000) msg="100k context window reached." ;;
  125000) msg="125k context window reached. Please start thinking about handing off the task." ;;
  150000) msg="150k context window reached. Please hand off the task ASAP." ;;
esac

jq -n --arg e "$event" --arg m "$msg" \
  '{hookSpecificOutput: {hookEventName: $e, additionalContext: $m}, systemMessage: $m}'
