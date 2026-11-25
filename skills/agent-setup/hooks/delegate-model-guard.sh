#!/usr/bin/env bash
# PreToolUse(mcp__t3[-_]code__delegate_task): a T3 delegation must name target.model from the agent-setup
# skill's models.yaml and an effort, otherwise the child inherits the parent's model.
# Shared by Claude and Codex. DELEGATE_MODEL_GUARD=0 disables.
set -u
input=$(cat)
[ "${DELEGATE_MODEL_GUARD:-1}" = "0" ] && exit 0
# The helper sits next to the real script; $0 may be a ~/.claude or ~/.codex symlink.
lib=$(dirname "$0")/_model-tiers.sh
[ -r "$lib" ] || lib=$(dirname "$(readlink "$0" 2>/dev/null || printf '%s' "$0")")/_model-tiers.sh
# shellcheck source=/dev/null
. "$lib" 2>/dev/null || exit 0 # no helper: nothing to check against

sel=$(printf '%s' "$input" | jq -c '.tool_input.target // {}' 2>/dev/null)
guard "Delegate model guard" "$(jq -r '.model // empty' <<<"$sel")" "$(effort_of "$(jq -c '.options' <<<"$sel")")" \
  "names no target.model, so the child would inherit this thread's model" \
  "Set target.model and the effort in target.options."
