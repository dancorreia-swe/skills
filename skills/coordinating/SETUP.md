# Setup

**Easiest:** ask your agent to "set up the coordinating skill". The `coordinating-setup`
skill checks what's in place, asks about models, shows the changes, then installs the
hooks and instructions below with a tested script (`--check`, `--dry-run`,
`--uninstall`). The rest of this page is the manual route.

The skill works on its own. Two optional extras make it stricter: guard hooks, and a
few lines in your global instructions. Paths assume a global install
(`npx skills add <owner>/skills -g`), which puts this folder at
`~/.agents/skills/coordinating`.

## 1. Pick your models

Copy [models.yaml](models.yaml) to `~/.config/coordinating/models.yaml` and edit the copy
(updates overwrite the installed one): one model per tier for each family you use (delete a family's blocks to stop using it) (Light, Mid,
Heavy), each with an effort. Use ids your hosts accept (T3: `orchestrator_capabilities`;
Orca: `orca orchestration worker-start --help`). Keep it plain block YAML; the hooks read
it with grep. To allow another id outside the tiers, add it under `extra_allowed` as
`- model: <id>`.

## 2. Hooks (optional)

They need `bash` and `jq`. All three take the same input in Claude Code and Codex.

| Hook | Event, matcher | What it does | Off switch |
|---|---|---|---|
| `hooks/delegate-model-guard.sh` | PreToolUse, `mcp__t3[-_]code__delegate_task` | Denies a T3 delegation whose model is missing or not in models.yaml, or that names no effort. | `DELEGATE_MODEL_GUARD=0` |
| `hooks/orca-model-guard.sh` | PreToolUse, `Bash` | The same for shell launches: Orca `worker-start`, `worktree create` and `agent launch` of claude/codex, and `t3 thread start`. | `ORCA_MODEL_GUARD=0` |
| `hooks/rotation-nudge.sh` | PostToolUse, `*` | Reminds the main agent to write its handoff and rotate at ~250k tokens (Claude) or ~190k (Codex), and at 25 orchestration rounds. | `ROTATION_NUDGE=0`; limits: `ROTATE_TOKENS`, `ROTATE_ROUNDS` |

`hooks/_model-tiers.sh` is a helper the two guards source; it is not a hook. Without
models.yaml the guards only check that a model is named.

**Claude Code**: merge into `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "mcp__t3[-_]code__delegate_task",
        "hooks": [{ "type": "command", "timeout": 5,
          "command": "bash \"$HOME/.agents/skills/coordinating/hooks/delegate-model-guard.sh\"" }] },
      { "matcher": "Bash",
        "hooks": [{ "type": "command", "timeout": 5,
          "command": "bash \"$HOME/.agents/skills/coordinating/hooks/orca-model-guard.sh\"" }] }
    ],
    "PostToolUse": [
      { "matcher": "*",
        "hooks": [{ "type": "command", "timeout": 5,
          "command": "bash \"$HOME/.agents/skills/coordinating/hooks/rotation-nudge.sh\"" }] }
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

Add to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` (use ~190k in the Codex one). The
first line makes agents load the skill without being asked. The last line lets a rotating
agent start its successor thread in T3 by itself; without it, it hands you the pointer.

```markdown
## Coordinating agents
- Before spawning any helper (Orca worker, T3 delegated task or thread, native subagent), picking a model or effort for one, coordinating, working a dispatched task, or handing off: load the `coordinating` skill.

## Context hygiene
- Hand off or compact? Check at the first of: ~250k tokens of context, any auto-compact warning, 25 orchestration rounds (`orca orchestration check`, `delegate_task` and `t3 thread start|send` calls), or a phase end (plan → build → verify, a wave boundary). Decide by the `coordinating` skill §6 table: coordinators, phase ends, a second compaction, a context full of wrong turns, or a different model next mean hand off (write the handoff and stop); one agent a few steps from done, on its first compaction, may keep going and let it compact.
- Handoff file path and sections: `coordinating` skill §6. Then launch the successor yourself (T3: new thread; Orca: new terminal; how: the skill's host map, "New owner") with the §6 pointer, reply with its link, and stop. This standing rule is my request for that new thread; ask me only if the launch fails.
```

## 4. Skills it calls on

Optional; the skill names them where they help: `diagnosing-bugs`, `code-review` and `pr`
(Matt Pocock's skills), `playwright-cli` (QA on staging), `computer-use` (GUI-only steps),
and in Orca, `orca-cli` and Orca's `orchestration` skill.
