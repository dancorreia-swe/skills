---
name: autopilot
description: Runs a backlog, epic or goal to done with the user out of the loop. One builder thread per ticket runs full-send or full-stop, and the coordinator only sizes, dispatches, tracks and reports. Use when the user says "autopilot", asks for an unattended or overnight run over several tickets, or says to stop asking and keep going.
---

# Autopilot

You are the coordinator of an unattended run. Builders own the work: each ticket gets its
own thread, which takes it to a merged or ready PR on its own (`full-send` / `full-stop`).
You keep the frontier moving and the user informed, and you never build, review or babysit
yourself. You are the run's judge, so you run Heavy (models.yaml); started on a lower tier,
write the run card, then hand off to a Heavy successor (section 5) before launching anyone.

**A builder's one line is its result.** Its thread, transcript, diff and logs stay with it:
you read none of them back. The only exception is a `blocked` line whose reason is unclear:
then open that one thread. PR state you need beyond the lines comes from one `gh pr view`.
Waiting on a PR is the builder's job, through `babysit-pr`: no `sleep` loops, no repeated
`gh pr checks`, here or in any brief.

The T3 Code commands for each step are in the host map,
[references/t3.md](references/t3.md); load it now.

Config lives in the `agent-setup` skill folder, and the user's copies in
`~/.config/agent-setup/` replace it:

- **Models:** [models.yaml](../agent-setup/models.yaml). Every launch names a model and an
  effort from it; read its header for the tier rules. An unavailable family: the same tier
  in your own family, in a fresh context, labelled "same-family".
- **Policy:** [autonomy.yaml](../agent-setup/autonomy.yaml). Under `merge: ask` (the
  default) builders run `full-stop`; under `merge: auto`, or when the user said "full send"
  for this run, they run `full-send`. Its `gates` are the only things that wait for the
  user (`full-send`, "Deciding").

Saying "autopilot" is the user's request for the builder threads this run launches.

## 1. Start

1. Write the **run card**, `~/.<project>-coordinator/RUN.md`:
   - the user's request, verbatim;
   - the done-criterion ("every ticket in epic #12 closed", "frontier empty");
   - the scope (labels, epic, milestone), the policy in force, the decisions file path;
   - host state: this thread's id, the heartbeat's `scheduledTaskId`;
   - a ticket table: `#n | size | tier | builder thread | state | PR`;
   - **START HERE**: what the next coordinator does first.
2. Build the frontier: open `ready-for-agent` tickets in scope with no open blockers (host
   map, "Tickets"). Size each ("Sizing"). Gate items are written as questions to the
   decisions file (`full-send`, "Deciding"), stay out of the run, and open the first
   digest. The coordinator asks in its digest, never with the question tool, so it stays
   free to wake; everything else goes ahead.
3. Prepare what a builder cannot do alone ("Helpers" has the roles):
   - **M** or a spec gap: a Planner turns it into a brief with steps and tests.
   - **L**: the Planner splits it into tickets, which join the frontier; a Designer for UI.
   - **Risky**: a `council` on the approach before its builder starts; the verdict goes in
     the brief.
   - **Unknown-cause bug**: a Diagnoser first (`diagnosing-bugs`); its root cause and
     failing test go in the brief.
4. Schedule the heartbeat (host map, "Heartbeat") unless `heartbeat_minutes` is 0. Prompt:

   > Heartbeat for the <topic> autopilot. Read <run card path>. If it says stopped,
   > disable this scheduled task and stop. If the coordinator thread it names is running,
   > stop. Otherwise send that thread one message, "Heartbeat: reconcile", and stop.

## 2. Launch builders

Up to `max_builders` at once, highest priority first; tickets touching the same code share a
builder, or run one after the other. Each builder is a top-level thread in its own worktree
(host map, "Builder thread"), launched with a preset model (`modelSelection`): the ticket's
tier, or Heavy when its review will be a council (M with 3 or more providers, counted as in
`council`, "Members"; L; Risky), because the builder judges that council.

The builder's first message is self-contained, because it sees none of your history:

- **Target:** the issue number; "read the issue, the issues it cites as 'Decided in', the
  glossary (`GLOSSARY.md`, `GLOSSARY-MAP.md` or `CONTEXT.md`) and the relevant ADRs".
- **Change:** what to build plus every acceptance criterion. Paste the triage "Agent brief"
  if there is one, never whole issue threads. Add the size, and any plan, council verdict
  or diagnosis from step 1.3.
- **Skill:** "Use the `full-send` skill" (or `full-stop`, per the policy).
- **Constraints:** glossary vocabulary, ADRs, AGENTS.md language rules, the ticket's scope,
  the decisions file path.
- **Ownership:** "You are a top-level thread that owns and watches its PR, not a
  `delegate_task` child. Your own worktree and branch; one PR against `main` with
  `Closes #<n>`."
- **Report:** "Report to coordinator thread `<id>` with one line, `#<n> <state> <PR url> —
  <detail>`, where state is `merged`, `ready`, `blocked` (detail: the reason), `gate`
  (detail: your question; send it before you ask) or `handoff` (detail: the handoff file).
  Your last action is that line."
- A relaunch also says: "Continue in place on branch `<branch>` / PR #<m> with
  `takeover`."

Record each builder's thread in the ticket table. Then end the turn.

## 3. Every wake

A builder's line, a helper's result, a heartbeat, or a user message. Keep the turn short:
read everything that arrived, update the table, dispatch what each result unblocks, end the
turn.

After processing, refresh the frontier (host map, "Tickets"): newly unblocked tickets join
it, and freed slots take the next ones. Then check the stop rule (section 5).

- **merged**: settle the builder thread. A ticket filed by
  `qa-sweep` gets a Light QA re-check on staging once it deploys (`qa-sweep`, step 3).
- **ready** (`full-stop`): keep it for the digest; the slot is free. Tickets blocked by an
  unmerged PR wait for the user's merge.
- **gate**: keep the question for the digest; the builder asks in its own thread, which
  waits in the user's inbox and sends a new line once answered. Its slot stays taken.
- **handoff**: relaunch the ticket at the same tier with the handoff file and
  `takeover` in the brief, plus this thread's id.
- **blocked**: relaunch it to continue in place, one tier up; already Heavy, an Advisor
  reads the reason first and its advice goes in the brief. A reason too unclear to brief
  from is the one case for opening the builder's thread. A second block parks the ticket
  with its reason.
- **"Heartbeat: reconcile"**: check each running builder's state once (host map, "List
  existing": running or ended) and its PR's latest commit, without reading its thread.
  Progress means a new commit, PR event or line since the last heartbeat. A builder that
  ended without its line gets one follow-up asking for it; one with no progress for two
  heartbeats is reported in the digest.
- **A user message** is steering: record it in the decisions file, apply it to the next
  launches, and message only the running builders whose task it changes.

## 4. Digest

The user's channel, sent as your reply. Send one when every builder from a launch round has
reported, when a heartbeat finds new state and the last digest is over 6 hours old, and at
the stop. At most 15 lines; detail stays in the run card:

- **Shipped:** merged PRs, one line each.
- **Ready for you:** PRs waiting for your merge (`full-stop`).
- **Decided for you:** new `auto` lines in the decisions file, with its path; "reply `Qn
  <option>` to overrule".
- **Waiting on you:** gate questions, each with its default and the thread asking it.
- **Parked:** blocked tickets and why.
- **Next:** what the next batch takes.

## 5. Rotate and stop

The coordinator holds little context, since builders do the work and state lives in GitHub
and the run card. When the context check fires (~250k tokens for Claude or ~190k for Codex,
an auto-compact warning, or 25 orchestration rounds; the global instructions' numbers win,
and the rotation nudge reminds you), the coordinator hands off rather than compacting:
update START HERE, then launch the successor on Heavy (host map, "New owner") with "Use
`takeover`: you are taking over the <topic> autopilot. Read <run card path> first." Reply
with its link and stop.

Stop when the done-criterion holds, or when every ticket left is gated, parked, or a ready
PR waiting for the user's merge: send the final digest, mark the run card stopped, and
disable the heartbeat. The user resumes it later with "take over the <topic> autopilot".

## Sizing

Smaller is the default. When torn between two sizes, start smaller and step up on evidence:
the same check failing twice, or the task proving bigger.

| Size | Typical signal | Crew |
|---|---|---|
| **XS** | Typo, copy, config value, dependency bump, rename. | One builder, Light. |
| **S** | Clear task, one area, testable as written. | One builder, Mid. |
| **M** | Several files, or a gap in the spec. | A Planner's brief, then one builder: Mid, or Heavy when its review is a council. |
| **L** | Cross-cutting, new feature, schema change, new UI surface. | A Planner splits it into tickets; a Designer for UI. |
| **Risky** (adds to any size) | Auth, payments, migrations, data deletion, secrets, public API. | A `council` on the approach before building; the builder runs one on the PR. |
| **Unknown-cause bug** | Broken, cause unknown. | A Diagnoser first; build once the cause is reproduced. |

## Helpers

A helper is your own subagent by default. Use a `delegate_task` when it needs its own
worktree, the other family, or must outlive the session. A builder is always a thread of its
own, because it owns and watches its PR. Brief a helper like a builder (target, change,
constraints), minus ownership, with the answer shape below.

| Role | Reach for it when | Tier | Gets back |
|---|---|---|---|
| **Planner** | M/L, or the path isn't obvious. Read-only. | Heavy | A brief: files, steps, tests, risks; for L, the split into tickets. |
| **Strategist** | Ordering a backlog, cutting scope. Product docs, not code. | Heavy | Order and cuts; open choices as decisions-file questions. |
| **Designer** | New or changed UI. | Mid; Heavy for a new pattern | UI spec covering empty/loading/error/success, or a throwaway prototype. |
| **QA** | Acceptance in a running app, device or suite (`qa-sweep`). | Mid; Light for re-checks | Pass/fail per criterion with evidence paths. |
| **Advisor** | A builder blocked twice, or a choice worth one outside read. Briefed without your preferred answer. | Heavy or second family | The pick, why, and the risk that would change it. |
| **Diagnoser** | Bug with unknown cause (`diagnosing-bugs`). | Heavy | Root cause, a failing test, suggested fix. |

Reviews come from `review-loop` or `council`, run by the builder that owns the PR.
