# Manual setup

**Easiest:** ask your agent to "set up the agent skills". The `agent-setup` skill checks
what's in place, asks about models, shows the changes, then installs the hooks and
instructions below with a tested script (`--check`, `--dry-run`, `--uninstall`). This page
is the manual route.

The skills work on their own. Two optional extras make them stricter: guard hooks, and a
few lines in your global instructions. Paths assume a global install
(`npx skills add <owner>/skills -g`), which puts this folder at
`~/.agents/skills/agent-setup`.

## 1. Pick your models

Copy [models.yaml](models.yaml) to `~/.config/agent-setup/models.yaml` and edit the copy
(updates overwrite the installed one): one Claude and one Codex model per tier (Light, Mid,
Heavy), each with an effort. Use ids your hosts accept (T3: `orchestrator_capabilities`). Keep it plain block YAML; the hooks read
it with grep. To allow another id outside the tiers, add it under `extra_allowed` as
`- model: <id>`. The `panel` list holds one Heavy member per family; add one for each
extra family you enable. With three or more, M changes get a council review too.

Copy [autonomy.yaml](autonomy.yaml) to `~/.config/agent-setup/autonomy.yaml` the same way
to change how far agents go alone: `merge` (`ask` or `auto` for autopilot runs), the `gates`
that always wait for you, `max_builders`, and the autopilot `heartbeat_minutes`.

## 2. Hooks (optional)

They need `bash` and `jq`. All three take the same input in Claude Code and Codex.

| Hook | Event, matcher | What it does | Off switch |
|---|---|---|---|
| `hooks/delegate-model-guard.sh` | PreToolUse, `mcp__t3[-_]code__delegate_task` | Denies a T3 delegation whose model is missing or not in models.yaml, or that names no effort. | `DELEGATE_MODEL_GUARD=0` |
| `hooks/thread-model-guard.sh` | PreToolUse, `mcp__t3[-_]code__t3_thread_launch` | Denies a new T3 thread with no `modelSelection`, a model not in models.yaml, or no effort, so every thread starts on a preset model. | `THREAD_MODEL_GUARD=0` |
| `hooks/rotation-nudge.sh` | PostToolUse, `*` | Reminds the main agent to hand off or compact at ~250k tokens (Claude) or ~190k (Codex), and at 25 orchestration rounds. | `ROTATION_NUDGE=0`; limits: `ROTATE_TOKENS`, `ROTATE_ROUNDS` |

`hooks/_model-tiers.sh` is a helper the two guards source; it is not a hook. Without
models.yaml the guards only check that a model and an effort are named.

**Claude Code**: merge into `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "mcp__t3[-_]code__delegate_task",
        "hooks": [{ "type": "command", "timeout": 5,
          "command": "bash \"$HOME/.agents/skills/agent-setup/hooks/delegate-model-guard.sh\"" }] },
      { "matcher": "mcp__t3[-_]code__t3_thread_launch",
        "hooks": [{ "type": "command", "timeout": 5,
          "command": "bash \"$HOME/.agents/skills/agent-setup/hooks/thread-model-guard.sh\"" }] }
    ],
    "PostToolUse": [
      { "matcher": "*",
        "hooks": [{ "type": "command", "timeout": 5,
          "command": "bash \"$HOME/.agents/skills/agent-setup/hooks/rotation-nudge.sh\"" }] }
    ]
  }
}
```

**Codex**: put the same `hooks` object in `~/.codex/hooks.json`, turn hooks on in
`~/.codex/config.toml`, then approve them once with `/hooks` inside Codex:

```toml
[features]
hooks = true
```

## 3. Global instructions (optional)

Add the block in [instructions.md](instructions.md) to `~/.claude/CLAUDE.md` and
`~/.codex/AGENTS.md`, with `{{SKILL_DIR}}` replaced by `~/.agents/skills/agent-setup` and
`{{ROTATE_TOKENS}}` by `250k` (Claude) or `190k` (Codex). The last line lets a rotating
agent start its successor thread by itself; without it, it hands you the pointer.

## 4. Skills they call on

The skills in this repo install together; `babysit-pr`'s `pr-wait` needs `python3` and an
authenticated `gh`. Optional, named where they help: `diagnosing-bugs`, `code-review` and
`pr` (Matt Pocock's skills), `playwright-cli` (QA on staging), `computer-use` (GUI-only
steps).
