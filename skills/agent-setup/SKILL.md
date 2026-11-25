---
name: agent-setup
description: Sets up this skill set on the machine for Claude Code and Codex, covering the model tiers (models.yaml), the autonomy policy (autonomy.yaml), the model-guard and rotation hooks, and the global-instruction block in CLAUDE.md / AGENTS.md. Use when the user asks to set up, install, check, update or remove these hooks, instructions or config, or to change the model tiers or autonomy policy.
---

# Agent setup

This folder holds the config the other skills read, and the hooks that enforce it:

- [models.yaml](models.yaml): the Light, Mid and Heavy tiers, a Claude and a Codex model
  each, the council's `panel`, and the rules for picking a tier (its header).
- [autonomy.yaml](autonomy.yaml): the `gates` that wait for the user, `merge` policy,
  `max_builders`, the autopilot heartbeat.
- [hooks/](hooks/): the guards and the rotation nudge (table below).

The user's own copies in `~/.config/agent-setup/` replace these; `npx skills update`
overwrites this folder.

Everything that touches agent config goes through `scripts/setup.sh`. It is idempotent,
backs up each file before changing it, skips anything already present (including hooks and
instructions the user set up by other means), and migrates what the older `coordinating` /
`coordinating-setup` skills installed. Use it rather than hand-editing `settings.json`,
`hooks.json`, `config.toml`, `CLAUDE.md` or `AGENTS.md`. It needs `bash` and `jq`.

## Steps

1. **Check.** Run `bash <this skill>/scripts/setup.sh --check`. If it prints "All set." and
   the user asked only for setup, say so and stop. A `STALE` line about the user's own
   lines loading the removed `coordinating` skill: show them [instructions.md](instructions.md)
   and offer to replace those lines with it.
2. **Models.** Show the user the tiers in `models.yaml` and ask once whether to keep them.
   Before using an id, check it exists: T3 `orchestrator_capabilities`, or the provider's
   model list. To change any, copy `models.yaml` to `~/.config/agent-setup/models.yaml` and
   edit the copy, keeping its plain block layout (the hooks read `model:` lines with grep).
   The user has only one provider: keep the other family's entries, and tell them reviews
   then run same-family (`council` falls back to a same-family council). Then show
   `autonomy.yaml` and ask once whether to keep it; changes go in
   `~/.config/agent-setup/autonomy.yaml` the same way.
3. **Plan.** Run `setup.sh --dry-run` and show the user its output. It changes global config
   for every session, so ask before going further. Narrow it if they want:
   `--agents claude` or `--agents codex`, `--no-hooks`, `--no-instructions`.
4. **Install.** Run `setup.sh` with the same options. Pass on what it prints: the backup
   folder; for Codex, that they must approve the new hooks once with `/hooks` inside Codex;
   and that open sessions need a restart.
5. **Verify.** Run `setup.sh --check` again; it must print "All set." for the agents chosen.
   Then confirm the guard denies an unlisted model:

   ```sh
   printf '%s' '{"tool_input":{"task":"x","target":{"model":"not-a-tier","options":{"effort":"low"}}}}' |
     bash <this skill>/hooks/delegate-model-guard.sh
   ```

   It should print JSON with `"permissionDecision":"deny"`.

## What it installs

| Piece | Where | Effect |
|---|---|---|
| `delegate-model-guard` | PreToolUse hook, T3 `delegate_task` | Denies a delegation with no model, a model not in models.yaml, or no effort. |
| `thread-model-guard` | PreToolUse hook, T3 `t3_thread_launch` | Denies a new thread with no `modelSelection`, a model not in models.yaml, or no effort, so every thread starts on a preset model. |
| `rotation-nudge` | PostToolUse hook, all tools | Reminds the main agent to hand off or compact at ~250k tokens (Claude) or ~190k (Codex), or 25 orchestration rounds. |
| Codex hooks switch | `[features] hooks = true` in `~/.codex/config.toml` | Codex runs hooks only with it. |
| Instructions block | `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, between `agent-setup:begin/end` markers | Repo changes run as `full-stop`; "full send" adds merging; "autopilot" grants its builder threads; every launch names a tier model; the hand-off-or-compact rule, with the successor thread as a standing request. |

Each hook has an off switch for one session: `DELEGATE_MODEL_GUARD=0`, `THREAD_MODEL_GUARD=0`,
`ROTATION_NUDGE=0`. The manual route (the same pieces by hand) is [MANUAL.md](MANUAL.md).

## Update or remove

- After `npx skills update`, run `setup.sh` again: it refreshes the instructions block if the
  template changed, adds any new hook, moves hooks still pointing at the old `coordinating`
  folder, and removes the retired `orca-model-guard`.
- `setup.sh --uninstall` removes only the hooks and block this script added. It leaves the
  Codex hooks switch and `~/.config/agent-setup/` alone; mention both.
