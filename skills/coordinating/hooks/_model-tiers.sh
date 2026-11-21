#!/usr/bin/env bash
# Sourced by delegate-model-guard.sh and orca-model-guard.sh; not a hook itself.
# Reads the model tiers (plain block YAML, so grep is enough) from the first that exists:
# $MODEL_TIERS_FILE, the user's override ~/.config/coordinating/models.yaml (survives
# `npx skills update`), then ../models.yaml in the skill folder this sits in.

if [ -z "${MODEL_TIERS_FILE:-}" ]; then
  MODEL_TIERS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/coordinating/models.yaml"
  [ -r "$MODEL_TIERS_FILE" ] ||
    MODEL_TIERS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/models.yaml"
fi

# Every id under a `model:` key (tiers and extra_allowed), one per line. Empty if no file.
allowed_models() {
  [ -r "$MODEL_TIERS_FILE" ] || return 0
  grep -E '^[[:space:]-]*model:[[:space:]]*[^[:space:]#]' "$MODEL_TIERS_FILE" |
    sed -E 's/^[[:space:]-]*model:[[:space:]]*//; s/[[:space:]]*(#.*)?$//; s/^["'\'']//; s/["'\'']$//' |
    sort -u
}

# "light: Claude claude-haiku-5-5/high, Codex gpt-6-luna/high; mid: ..." for deny messages.
# A family left out of the file is left out of the summary.
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
        s = ""
        if ((t, "claude") in m) s = s "Claude " m[t, "claude"] "/" e[t, "claude"]
        if ((t, "codex") in m) s = s (s != "" ? ", " : "") "Codex " m[t, "codex"] "/" e[t, "codex"]
        printf "%s%s: %s", (i > 1 ? "; " : ""), t, s
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
