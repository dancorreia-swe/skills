#!/usr/bin/env bash
# Installs, checks or removes the agent-setup skill's hooks and global-instruction block
# for Claude Code and Codex. Idempotent: anything already present (ours or the user's own)
# is left alone; hooks and a block from the older coordinating skill are migrated.
# Every file it changes is backed up first.
#
#   setup.sh --check              report what is in place; exit 1 if something is missing
#   setup.sh --dry-run            show what install would change, change nothing
#   setup.sh                      install
#   setup.sh --uninstall          remove only what this script added
#   options: --agents claude,codex   (default: the ones found on this machine)
#            --no-hooks | --no-instructions
set -euo pipefail

MODE=install AGENTS="" DO_HOOKS=1 DO_TEXT=1
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check ;;
    --dry-run) MODE=dry ;;
    --uninstall) MODE=uninstall ;;
    --agents) AGENTS=${2:?--agents needs a list}; shift ;;
    --agents=*) AGENTS=${1#*=} ;;
    --no-hooks) DO_HOOKS=0 ;;
    --no-instructions) DO_TEXT=0 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "setup.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "setup.sh: $*" >&2; exit 2; }
command -v jq >/dev/null || die "jq is required (brew install jq / apt install jq)"

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
[ -d "$SKILL_DIR/hooks" ] && [ -f "$SKILL_DIR/instructions.md" ] || die "no hooks/ or instructions.md in $SKILL_DIR"

# Hook commands use $HOME so the settings stay valid if the home path changes; the
# instructions name the skill folder with ~.
HOME_P=$(cd "$HOME" && pwd -P)
case "$SKILL_DIR" in
  "$HOME_P"/*) HOOK_DIR_CMD="\$HOME${SKILL_DIR#"$HOME_P"}/hooks" SKILL_DIR_TXT="~${SKILL_DIR#"$HOME_P"}" ;;
  *) HOOK_DIR_CMD="$SKILL_DIR/hooks" SKILL_DIR_TXT=$SKILL_DIR ;;
esac
LEGACY_HOOK_DIR="/coordinating/hooks/" # where the coordinating skill kept the same hooks

CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
CODEX_DIR=${CODEX_HOME:-$HOME/.codex}
if [ -z "$AGENTS" ]; then
  { [ -d "$CLAUDE_DIR" ] || command -v claude >/dev/null; } && AGENTS="claude"
  { [ -d "$CODEX_DIR" ] || command -v codex >/dev/null; } && AGENTS="${AGENTS:+$AGENTS,}codex"
  [ -n "$AGENTS" ] || die "found neither Claude Code (~/.claude) nor Codex (~/.codex); pass --agents"
fi

HOOKS=( # name|event|matcher
  "delegate-model-guard|PreToolUse|mcp__t3[-_]code__delegate_task"
  "thread-model-guard|PreToolUse|mcp__t3[-_]code__t3_thread_launch"
  "rotation-nudge|PostToolUse|*"
)
RETIRED=( # name|event: hooks this skill (or coordinating) used to install; ours get removed
  "orca-model-guard|PreToolUse"
)
BEGIN_MARK="<!-- agent-setup:begin (managed by the agent-setup skill; edit outside this block) -->"
END_MARK="<!-- agent-setup:end -->"
LEGACY_BEGIN="<!-- coordinating-setup:begin (managed by the coordinating-setup skill; edit outside this block) -->"
LEGACY_END="<!-- coordinating-setup:end -->"
BACKUP_DIR="$HOME/.agents/backups/agent-setup/$(date +%Y%m%d-%H%M%S)"
MISSING=0 CHANGED=0

say() { printf '  %-7s %s\n' "$1" "$2"; }
backup() { # file
  [ -f "$1" ] || return 0
  mkdir -p "$BACKUP_DIR"
  cp -p "$1" "$BACKUP_DIR/$(printf '%s' "$1" | sed "s|^$HOME/||; s|^\.||; s|/|__|g")"
}
write() { # file content: back up, then replace
  backup "$1"
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1.tmp.$$" && mv "$1.tmp.$$" "$1"
  CHANGED=1
}

# ---- hooks (settings.json for Claude, hooks.json for Codex: same "hooks" shape) ----
hooks_file() { # agent label file
  local label=$1 f=$2 json name event matcher cmd found new legacy
  json='{}'
  if [ -f "$f" ]; then json=$(jq '.' "$f") || die "$f is not valid JSON; fix it first"; fi
  new=$json
  for h in "${HOOKS[@]}"; do
    IFS='|' read -r name event matcher <<<"$h"
    cmd="bash \"$HOOK_DIR_CMD/$name.sh\""
    found=$(jq -r --arg ev "$event" --arg n "/$name.sh" \
      '[.hooks[$ev][]?.hooks[]?.command // empty | select(contains($n))] | first // empty' <<<"$new")
    legacy=0
    [ -n "$found" ] && [ "$found" != "$cmd" ] && [[ $found == *"$LEGACY_HOOK_DIR$name.sh"* ]] && legacy=1
    case "$MODE" in
      check)
        if [ "$legacy" = 1 ]; then say STALE "$label: $name hook points at the old coordinating skill ($found)"; MISSING=1
        elif [ -n "$found" ]; then say ok "$label: $name hook ($found)"
        else say MISSING "$label: $name hook"; MISSING=1; fi ;;
      uninstall)
        [ "$found" = "$cmd" ] || [ "$legacy" = 1 ] || { [ -n "$found" ] && say keep "$label: $name hook is not ours ($found)"; continue; }
        new=$(drop_hook "$event" "$found" <<<"$new")
        say remove "$label: $name hook" ;;
      *)
        if [ "$legacy" = 1 ]; then
          new=$(jq --arg ev "$event" --arg old "$found" --arg c "$cmd" \
            '.hooks[$ev] |= map(.hooks |= map(if .command == $old then .command = $c else . end))' <<<"$new")
          say update "$label: $name hook moves from the coordinating skill to $HOOK_DIR_CMD"; continue
        fi
        if [ -n "$found" ]; then say skip "$label: $name hook already registered ($found)"; continue; fi
        new=$(jq --arg ev "$event" --arg m "$matcher" --arg c "$cmd" \
          '.hooks[$ev] = ((.hooks[$ev] // []) + [{matcher: $m, hooks: [{type: "command", command: $c, timeout: 5}]}])' <<<"$new")
        say add "$label: $name hook ($event, matcher $matcher)" ;;
    esac
  done
  for h in "${RETIRED[@]}"; do
    IFS='|' read -r name event <<<"$h"
    found=$(jq -r --arg ev "$event" --arg n "/$name.sh" \
      '[.hooks[$ev][]?.hooks[]?.command // empty | select(contains($n))] | first // empty' <<<"$new")
    [ -n "$found" ] || continue
    if [[ $found != *"/agent-setup/hooks/$name.sh"* && $found != *"$LEGACY_HOOK_DIR$name.sh"* ]]; then
      say keep "$label: $name hook is not ours ($found)"; continue
    fi
    if [ "$MODE" = check ]; then say STALE "$label: $name hook is retired; run setup.sh to remove it"; MISSING=1; continue; fi
    new=$(drop_hook "$event" "$found" <<<"$new")
    say remove "$label: $name hook (retired)"
  done
  if [ "$MODE" != check ] && [ "$MODE" != dry ] && [ "$new" != "$json" ]; then write "$f" "$new"; fi
}

drop_hook() { # event command: remove that command from stdin's hooks, pruning empty entries
  jq --arg ev "$1" --arg c "$2" '
    .hooks[$ev] |= (map(.hooks |= map(select(.command != $c))) | map(select((.hooks | length) > 0)))
    | if (.hooks[$ev] | length) == 0 then del(.hooks[$ev]) else . end
    | if (.hooks | length) == 0 then del(.hooks) else . end'
}

codex_features() { # make sure [features] hooks = true in config.toml
  local f="$CODEX_DIR/config.toml" state
  state=$(awk '/^\[/{s=($0=="[features]")} s&&/^[[:space:]]*hooks[[:space:]]*=/{v=$0} END{print v}' "$f" 2>/dev/null || true)
  case "$MODE" in
    check)
      if printf '%s' "$state" | grep -Eq '=[[:space:]]*true'; then say ok "codex: [features] hooks = true"
      else say MISSING "codex: [features] hooks = true in config.toml"; MISSING=1; fi ;;
    uninstall) say keep "codex: [features] hooks left as is (other hooks may need it)" ;;
    *)
      if printf '%s' "$state" | grep -Eq '=[[:space:]]*true'; then say skip "codex: hooks already enabled"; return; fi
      say set "codex: [features] hooks = true in config.toml"
      [ "$MODE" = dry ] && return
      local content=""
      [ -f "$f" ] && content=$(cat "$f")
      if [ -n "$state" ]; then # hooks = false (or other) inside [features]
        content=$(awk '/^\[/{s=($0=="[features]")} s&&/^[[:space:]]*hooks[[:space:]]*=/{$0="hooks = true"} {print}' <<<"$content")
      elif grep -q '^\[features\]' <<<"$content"; then
        content=$(awk '{print} $0=="[features]"{print "hooks = true"}' <<<"$content")
      else
        content="${content:+$content
}
[features]
hooks = true"
      fi
      write "$f" "$content" ;;
  esac
}

# ---- global instructions block ----
instructions_file() { # label file tokens
  local label=$1 f=$2 tokens=$3 content="" block has_ours=0 has_other=0 has_legacy=0 current=""
  [ -f "$f" ] && content=$(cat "$f")
  # The coordinating-setup skill's block is ours under its old markers: rename them, then
  # it updates like any outdated block.
  content=$(LB=$LEGACY_BEGIN LE=$LEGACY_END B=$BEGIN_MARK E=$END_MARK awk \
    '$0==ENVIRON["LB"]{$0=ENVIRON["B"]} $0==ENVIRON["LE"]{$0=ENVIRON["E"]} {print}' <<<"$content")
  grep -qF "$BEGIN_MARK" <<<"$content" && has_ours=1
  block="$BEGIN_MARK
$(sed "s/{{ROTATE_TOKENS}}/$tokens/; s|{{SKILL_DIR}}|$SKILL_DIR_TXT|g" "$SKILL_DIR/instructions.md")
$END_MARK"
  local stripped
  stripped=$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '$0==b{skip=1} !skip{print} $0==e{skip=0}' <<<"$content")
  [ "$has_ours" = 1 ] && current=$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '$0==b{p=1} p{print} $0==e{p=0}' <<<"$content")
  # The user's own lines (outside our block): the same rules already, or older ones that
  # still load the removed coordinating skill.
  # shellcheck disable=SC2016 # literal backticks
  if grep -q 'agent-setup/models.yaml' <<<"$stripped"; then has_other=1
  elif grep -q 'the `coordinating` skill' <<<"$stripped"; then has_legacy=1; fi
  case "$MODE" in
    check)
      if [ "$has_legacy" = 1 ]; then
        say STALE "$label: your own lines in $f load the removed coordinating skill; replace them with instructions.md"; MISSING=1
      elif [ "$has_ours" = 1 ] && [ "$current" != "$block" ]; then
        say STALE "$label: instructions block in $f is out of date"; MISSING=1
      elif [ "$has_ours" = 1 ] || [ "$has_other" = 1 ]; then say ok "$label: instructions in $f"
      else say MISSING "$label: instructions in $f"; MISSING=1; fi ;;
    uninstall)
      [ "$has_ours" = 1 ] || return 0
      say remove "$label: instructions block in $f"
      write "$f" "$stripped" ;; # $(...) already dropped the trailing blank lines
    *)
      if [ "$has_legacy" = 1 ]; then
        say skip "$label: your own lines in $f load the removed coordinating skill; replace them with instructions.md, then run this again"; return
      fi
      if [ "$has_other" = 1 ] && [ "$has_ours" = 0 ]; then say skip "$label: $f already has these rules (your own lines)"; return; fi
      if [ "$has_ours" = 1 ]; then
        [ "$current" = "$block" ] && { say skip "$label: instructions block up to date"; return; }
        say update "$label: instructions block in $f"
        [ "$MODE" = dry ] && return
        write "$f" "$(BLK=$block awk -v b="$BEGIN_MARK" -v e="$END_MARK" \
          '$0==b{print ENVIRON["BLK"]; skip=1; next} $0==e{skip=0; next} !skip{print}' <<<"$content")"
      else
        say add "$label: instructions block to $f"
        [ "$MODE" = dry ] && return
        write "$f" "${content:+$content

}$block"
      fi ;;
  esac
}

# ---- run ----
echo "agent-setup: $MODE for $AGENTS (skill: $SKILL_DIR)"
IFS=',' read -r -a list <<<"$AGENTS"
for a in "${list[@]}"; do
  case "$a" in
    claude)
      [ "$DO_HOOKS" = 1 ] && hooks_file claude "$CLAUDE_DIR/settings.json"
      [ "$DO_TEXT" = 1 ] && instructions_file claude "$CLAUDE_DIR/CLAUDE.md" 250k ;;
    codex)
      if [ "$DO_HOOKS" = 1 ]; then hooks_file codex "$CODEX_DIR/hooks.json"; codex_features; fi
      [ "$DO_TEXT" = 1 ] && instructions_file codex "$CODEX_DIR/AGENTS.md" 190k ;;
    *) die "unknown agent '$a' (use claude, codex)" ;;
  esac
done

# Models: the user's override survives `npx skills update`.
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
for y in models autonomy; do
  if [ -r "$CONF/agent-setup/$y.yaml" ]; then say ok "$y: your picks in $CONF/agent-setup/$y.yaml"
  elif [ -r "$CONF/coordinating/$y.yaml" ]; then
    say info "$y: your picks in $CONF/coordinating/$y.yaml (older name; move it to $CONF/agent-setup/)"
  else say info "$y: skill defaults ($SKILL_DIR/$y.yaml); copy it to $CONF/agent-setup/$y.yaml to change them"; fi
done

case "$MODE" in
  check)
    if [ "$MISSING" = 0 ]; then echo "All set."
    else echo "Some parts are missing; run setup.sh to add them."; exit 1; fi ;;
  dry) echo "Dry run: nothing changed." ;;
  *)
    if [ "$CHANGED" = 1 ]; then
      echo "Done. Backups: $BACKUP_DIR"
      case ",$AGENTS," in *,codex,*) [ "$MODE" = install ] && [ "$DO_HOOKS" = 1 ] &&
        echo "Codex: open Codex and approve the new hooks once with /hooks." ;; esac
      echo "Restart open Claude Code / Codex sessions to load the changes."
    else
      echo "Nothing to change."
    fi ;;
esac
