#!/usr/bin/env bash
# Sourced by delegate-model-guard.sh and thread-model-guard.sh; not a hook itself.
# Reads the model tiers (plain block YAML, so grep is enough) from the first that exists:
# $MODEL_TIERS_FILE, the user's override ~/.config/agent-setup/models.yaml (survives
# `npx skills update`; ~/.config/coordinating/ is its older name), then ../models.yaml in the
# skill folder this sits in.

if [ -z "${MODEL_TIERS_FILE:-}" ]; then
  for MODEL_TIERS_FILE in "${XDG_CONFIG_HOME:-$HOME/.config}"/{agent-setup,coordinating}/models.yaml \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/models.yaml"; do
    [ -r "$MODEL_TIERS_FILE" ] && break
  done
fi

# Every id under a `model:` key (tiers and extra_allowed), one per line. Empty if no file.
allowed_models() {
  [ -r "$MODEL_TIERS_FILE" ] || return 0
  grep -E '^[[:space:]-]*model:[[:space:]]*[^[:space:]#]' "$MODEL_TIERS_FILE" |
    sed -E 's/^[[:space:]-]*model:[[:space:]]*//; s/[[:space:]]*(#.*)?$//; s/^["'\'']//; s/["'\'']$//' |
    sort -u
}

# "light: Claude claude-haiku-5-5/high, Codex gpt-6-luna/high; mid: ..." for deny messages.
tiers_summary() {
  [ -r "$MODEL_TIERS_FILE" ] || return 0
  awk '
    /^tiers:/ { in_t = 1; next }
    in_t && /^[^[:space:]#]/ { in_t = 0 }
    !in_t { next }
    /^  [a-z_]+:/ { t = $1; sub(":", "", t); next }
    /^    (claude|codex):/ { f = $1; sub(":", "", f); next }
    /^      model:/ { m[t, f] = $2 }
    /^      effort:/ { e[t, f] = $2; if (!(t in seen)) { seen[t] = 1; order[++n] = t } }
    END {
      for (i = 1; i <= n; i++) {
        t = order[i]
        printf "%s%s: Claude %s/%s, Codex %s/%s", (i > 1 ? "; " : ""), t,
          m[t, "claude"], e[t, "claude"], m[t, "codex"], e[t, "codex"]
      }
    }' "$MODEL_TIERS_FILE"
}

# model_allowed <id>: true if listed, or if there is no models.yaml to check against.
model_allowed() {
  local list
  list=$(allowed_models)
  [ -z "$list" ] && return 0
  printf '%s\n' "$list" | grep -Fxq -- "$1"
}

# effort_of <json>: the effort in a T3 options value, either {"effort": …} or
# [{"id": "effort", "value": …}] (Codex: reasoningEffort). Empty if none.
effort_of() {
  printf '%s' "$1" | jq -r '
    . // {} | if type == "array" then (map({key: .id, value: .value}) | from_entries) else . end
    | (.effort // .reasoningEffort // empty) | tostring' 2>/dev/null
}

# guard <label> <model> <effort> <no-model problem> <fix hint>: allow (print nothing) or
# print a PreToolUse deny naming the problem and the tiers.
guard() {
  local label=$1 model=$2 effort=$3 problem="" tiers
  if [ -z "$model" ]; then problem=$4
  elif ! model_allowed "$model"; then problem="uses '$model', which is not a tier in models.yaml"
  elif [ -z "$effort" ]; then problem="names no effort in its options (Claude: effort; Codex: reasoningEffort)"
  fi
  [ -z "$problem" ] && return 0
  tiers=$(tiers_summary)
  jq -n --arg r "$label: this call $problem. Pick a tier from $MODEL_TIERS_FILE${tiers:+ ($tiers)}; its header has the rules (smallest tier that fits, your own family first, the other family for review). $5 Heavy is fine when chosen on purpose. An id outside the tiers needs an extra_allowed entry in models.yaml first." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
}
