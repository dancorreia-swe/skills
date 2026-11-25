#!/usr/bin/env bash
# PostToolUse(*): nudges the main agent to hand off or compact (autopilot section 5, full-send "Context").
# Fires once when context reaches ROTATE_TOKENS (default 250000; 190000 for Codex, whose window is ~258k),
# then every further 20k, and once at ROTATE_ROUNDS orchestration rounds (default 25: delegate_task,
# t3_thread_launch and t3_thread_send calls, and the t3 CLI's thread start|send run from a shell),
# then every further 10.
# Calls within ROUND_WINDOW seconds (default 120) of the last counted one are the same round: a panel
# or a fan-out sent in one message counts once.
# Main agent only. ROTATION_NUDGE=0 disables.
set -u
input=$(cat)
[ "${ROTATION_NUDGE:-1}" = "0" ] && exit 0
[ -n "$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)" ] && exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)
f="${TMPDIR:-/tmp}/rotation-nudge-${sid}"
{ read -r rounds tok_band round_band last_round < "$f"; } 2>/dev/null || { rounds=0; tok_band=0; round_band=0; }
last_round=${last_round:-0}; now=$(date +%s)

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
cmd=$(printf '%s' "$input" | jq -r '.tool_input | if type == "object" then (.command // .cmd // .input // "") else (. // "") end | if type == "array" then join(" ") else tostring end' 2>/dev/null)
# A shell command counts when it runs one of these (not when text only mentions it).
runs_round() {
  printf '%s\n' "$cmd" | tr ';&|()`' '\n' | grep -Eq \
    "^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((env|command|exec|nohup)[[:space:]]+)*([^[:space:]]*/)?t3[[:space:]]+thread[[:space:]]+(start|send)([[:space:]]|$)"
}
if [[ $tool =~ ^mcp__t3[-_]code__(delegate_task|t3_thread_launch|t3_thread_send)$ ]] || { [ "$tool" = "Bash" ] && runs_round; }; then
  if [ $((now - last_round)) -ge "${ROUND_WINDOW:-120}" ]; then rounds=$((rounds + 1)); fi
  last_round=$now
fi

tokens=0; default_t=250000
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$tp" ] && [ -r "$tp" ]; then
  # Claude transcript: assistant usage; Codex rollout: token_count events (input_tokens includes cached)
  tokens=$(tail -n 40 "$tp" | jq -r '
    if .type == "assistant" and (.isSidechain | not) then .message.usage | select(. != null)
      | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
    elif .type == "event_msg" and .payload.type == "token_count" then .payload.info.last_token_usage.input_tokens // empty
    else empty end' 2>/dev/null | tail -n 1)
  tokens=${tokens:-0}
  tail -n 40 "$tp" | grep -q "\"type\":\"event_msg\"" && default_t=190000 # Codex rollout
fi

limit_t=${ROTATE_TOKENS:-$default_t}; limit_r=${ROTATE_ROUNDS:-25}
msg=""
if [ "$tokens" -ge "$limit_t" ]; then
  band=$(( (tokens - limit_t) / 20000 + 1 ))
  [ "$band" -gt "$tok_band" ] && { tok_band=$band; msg="context is at ~$((tokens / 1000))k tokens"; }
fi
if [ "$rounds" -ge "$limit_r" ]; then
  band=$(( (rounds - limit_r) / 10 + 1 ))
  [ "$band" -gt "$round_band" ] && { round_band=$band; msg="${msg:+$msg and }this session has run $rounds orchestration rounds"; }
fi
echo "$rounds $tok_band $round_band $last_round" > "$f"
[ -z "$msg" ] && exit 0
jq -n --arg c "Rotation nudge: $msg. Hand off or compact? Decide now. A coordinator (autopilot) hands off: autopilot section 5. Anyone else (a builder: one thread, one PR) keeps going and lets it compact, writing what a summary must not lose to a notes file first, and hands off on a second compaction, a context full of wrong turns, or a different model next (full-send, \"Context\"). To hand off: finish the current step, write the run card's START HERE or a handoff file (takeover, \"Writing a handoff file\"), launch the successor yourself with \"Use takeover\" and the file path, reply with its link, and stop. A builder under a coordinator reports handoff to it instead of launching." \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
