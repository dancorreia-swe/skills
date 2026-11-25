---
name: full-send
description: Takes one change or ticket all the way to a merged PR with nobody watching. Use when the user says "full send", or when an autopilot brief or a coordinator's builder brief says to use it.
---

# Full Send

Adapted from [tstack](https://github.com/t3dotgg/tstack) (MIT, Theo Browne).

The user is not watching this thread. Your updates and your final message go unread until
long after you stop. You own the work from its current state to a merged PR. Run it only
when the user said "full send" in some clear way, or a brief from a coordinator or an
autopilot run told you to; otherwise ask before merging.

The request grants you permission to:

- Merge the PR once the merge gate passes.
- Force-push the PR's own branch with `--force-with-lease` after a rebase.
- Use the test methods that Proof needs, without asking first.

## Testing permission

The request is the permission. A project file that says to ask before a test method, or to
leave testing to the user, is replaced for this task: computer use, browser automation,
simulators and devices, the app or a dev server, screenshots and visual checks. Use the
method that gives direct proof and list it in the report. Rules about *how* to test (the
right command, fixture or check) still apply. The grant covers only the tests this task
needs; it adds nothing to the gates ("Deciding"), and a harness approval prompt still stands.

## Steps

1. **Read the target.** The ticket, the issues it cites as "Decided in", the glossary
   (`GLOSSARY.md`, `GLOSSARY-MAP.md` or `CONTEXT.md`), relevant ADRs and AGENTS.md. Link the
   ticket to your thread and mark it started (T3: `link_issue`, then `set_issue_state`;
   without T3, `Closes #<n>` in the PR is enough).
2. **Finish the change** with the smallest change that works. Fix the case that happened.
   Off the default branch first. While building, run only the tests the change affects
   (`vitest related`, `jest --findRelatedTests`, `pytest <paths>`, `go test ./<pkg>/...`)
   plus lint and type-check. Fix a dependency with a release that has the fix, never by
   patching `node_modules`. Run commands and GUI-only steps yourself (`computer-use`). A
   task bigger than briefed goes back to the coordinator, when there is one, as a `blocked`
   line whose detail is what you learned.
3. **Prove it.** Proof covers every change in the diff (see "Proof").
4. **Get review**, by the change's size (the brief's, or judge it yourself):
   - **XS/S** (one area, testable as written): `review-loop`.
   - **M** (several files, or a gap in the spec): `council` when 3 or more providers are
     available (`council`, "Members"); otherwise `review-loop`.
   - **L** (cross-cutting, new feature, schema change, new UI surface) or **Risky** (auth,
     payments, migrations, data deletion, secrets, public API): `council`.
5. **File the PR.** Rebase onto the latest default branch. Write the body (with the `pr`
   skill when it is installed): the problem first, `Closes #<n>`, acceptance criteria
   ticked, one line on how you proved it, the review result line, and a **Decided for you**
   list. A real PR, not a
   draft, so review bots run. GraphQL rate limit used up: `gh api
   repos/<owner>/<repo>/pulls -f title=… -f head=… -f base=… -F body=@<file>`. Link it
   (T3: `link_pull_request`).
6. **Babysit** with `babysit-pr`. Fix real findings and CI failures; prove each fix before
   pushing it. Every wait on the PR goes through `babysit-pr`'s watcher, which wakes you:
   no `sleep` loops, no repeated `gh pr checks`.
7. **Merge** when the merge gate passes.
8. **Report** (see "Report").

Stay active from step 1 to step 8. End a turn only with `babysit-pr`'s watcher armed, so the
PR's next change wakes you; nobody else will prompt you. Stopping before the merge: unwatch
first.

Started by `delegate_task` (your task came from a `delegate_task` call, not a thread
launch)? Then you are a child, and children never watch a PR: stop after step 5 and return
the PR link; the parent babysits and merges. A top-level thread launched for a ticket owns
its PR, whatever its `delegatedFrom` says.

## Proof

Proof is evidence you observed yourself in this session: command output, a reproduction, a
screenshot. Use the most direct proof the change allows:

- Reproduce the original failure, apply the fix, watch the same reproduction pass.
- Run the checks the repo's CI runs (type-check, lint, the affected tests).
- Add one focused test that fails without the fix, when the behaviour has none and the repo
  has a test setup.
- UI and runtime behaviour: run the app and look at the change; a QA helper with the
  acceptance criteria does the device or browser loop (`qa-sweep`, "Device loops"). Green
  mocked tests do not prove the user experience works.

A change you cannot prove is a change you are not confident in: ask.

## Merge gate

All true on the latest commit:

- Proof covers every change in the diff.
- Required checks are green.
- Review bots have finished; each finding is fixed or dismissed with a written reason.
- The review loop or council approved the current behaviour diff.
- No human review still requests changes.
- The branch is up to date with the default branch and GitHub reports it mergeable.
- Merging deploys nothing to production. A workflow that deploys on push to the default
  branch makes the merge a gate ("Deciding"): stop at ready and ask.

Merge with the method the repo uses (allowed methods, recent merged PRs). With a merge queue
or auto-merge, stay until GitHub reports the PR merged. Merge through branch protection as
configured; never `--admin` or another bypass. After the merge: remove the worktree and
temp files, mark the ticket done.

## Deciding

**Gates** are the only things that wait for the user: the `gates` list in autonomy.yaml
(`~/.config/agent-setup/autonomy.yaml`, else [the default](../agent-setup/autonomy.yaml));
read it. A gate parks only its own item; the rest of the work moves on.

Settle every other open choice at the first step that fits:

1. **Already decided:** the issue, its "Decided in" issues, the glossary, an ADR or the
   decisions file answers it. Act and cite it.
2. **Reversible and local** (naming, layout, a library within the stack, an internal API
   shape): take the most reversible sensible option, list it under **Decided for you** in
   the PR body, keep going.
3. **Lasting** (ADR-level, an architecture or data-model choice): a `council` on the choice.
   Agreement: **decide-and-log**, adding `Qn (auto, <date>): (<option>) <one line>; council
   <tally>; undo: <how>` to the decisions file, then act. The user overrules by answering
   `Qn <option>`; the overrule becomes a ticket or a revert.
4. **A gate, or a council still split:** ask the user (below).

Two more cases end without asking:

- A change you cannot prove: stop at ready, unmerged, with "Unproven: <what and why>" at the
  top of the PR body. Report `ready`.
- A merge gate you cannot make pass yourself, or another PR that makes this one obsolete:
  report `blocked` with the reason and the PR link; closing a PR waits for authorization.

**The decisions file** is `~/.<project>-handoffs/decisions-<topic>.md`: questions numbered
`Q1…Qn`, lettered options `(a)/(b)/(c)`, your recommendation marked as the default on each.
Record each answer the moment it arrives, one line per Q with the chosen option and date.
"Q1 a, Q2 b…" records those; "agree with all recommendations" (or "Aceito todas…") records
every default. Then proceed through all of it without asking again. Cite
`decisions-<topic>.md#Qn` when acting on a decision, and re-read the file after any
compaction or handoff. Lasting decisions also go into an ADR when the ticket asks.

**Asking.** Write the questions to the decisions file and batch them into one ask. When a
coordinator launched you, report the `gate` line first. Unwatch the PR, then ask with the
harness's question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex),
so the thread shows it is waiting. Put all the context in the question: the PR link, what
blocks you, the options with your recommendation first. Once answered, record it, watch the
PR again and carry on. No question tool, or no answer: take the safe path, leave the PR open
and unmerged, and start your final message with the question.

## Context

One thread per PR keeps most runs short of a compaction. When the context check fires (the
global instructions or the rotation nudge), write what a summary must not lose (the
hypothesis, the failing test, files touched, decisions made) to a notes file in the
worktree, let it compact, and re-read the notes. A second compaction on this ticket, a
context full of wrong turns, or a next stretch that needs another model: write a handoff
file (`takeover`, "Writing a handoff file"), unwatch the PR, report `#<n> handoff <PR url> —
<path>` to the coordinator, and stop. With no coordinator, launch the successor yourself
with "Use `takeover`: you are taking over <topic>. Read <path> first." (T3:
`t3_thread_launch` with that `message` and a preset `modelSelection`: your own model and
effort, or the tier the next stretch needs). Reply with its link, and stop.

## Report

Final message: the PR link, the merge commit, your proof, the review result, and each
decision you made for the user. Detail beyond a few lines goes in the PR body.

Launched by a coordinator (the brief names a coordinator thread): your last
action is one line back to it, in the format the brief gives (`#<n> <state> <PR url> —
<detail>`; `t3_thread_send` to that thread).
