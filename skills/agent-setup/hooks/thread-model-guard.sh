#!/usr/bin/env bash
# PreToolUse(mcp__t3[-_]code__t3_thread_launch): a new T3 thread is launched with a preset model:
# modelSelection naming a model from the agent-setup skill's models.yaml and an effort.
# Without it the thread inherits the launcher's model, which is right only by accident.
# Shared by Claude and Codex. THREAD_MODEL_GUARD=0 disables.
set -u
input=$(cat)
[ "${THREAD_MODEL_GUARD:-1}" = "0" ] && exit 0
# The helper sits next to the real script; $0 may be a ~/.claude or ~/.codex symlink.
lib=$(dirname "$0")/_model-tiers.sh
[ -r "$lib" ] || lib=$(dirname "$(readlink "$0" 2>/dev/null || printf '%s' "$0")")/_model-tiers.sh
# shellcheck source=/dev/null
. "$lib" 2>/dev/null || exit 0 # no helper: nothing to check against

sel=$(printf '%s' "$input" | jq -c '.tool_input.modelSelection // {}' 2>/dev/null)
guard "Thread model guard" "$(jq -r '.model // empty' <<<"$sel")" "$(effort_of "$(jq -c '.options' <<<"$sel")")" \
  "has no modelSelection, so the thread would inherit this thread's model" \
  "Set modelSelection {instanceId, model, options} (options: [{id: effort, value: …}]; Codex: reasoningEffort), naming your own model and effort when the thread should continue on them."
