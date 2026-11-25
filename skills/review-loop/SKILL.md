---
name: review-loop
description: Reviews a change with a second-family model in a loop until both agree, on a round budget with a findings ledger. Use when the user says "review loop" or "sol loop", or when full-send's review step picks it (S changes, or M with fewer than 3 providers).
---

# Review loop

Adapted from tstack's `sol-loop` ([tstack](https://github.com/t3dotgg/tstack), MIT, Theo
Browne).

Make the most minimal changes that satisfy the reviewer. Watch for scope creep, and push
back when a finding is wrong.

## Reviewer

The second family from yours (Claude → Codex, Codex → Claude): its Mid model from
[models.yaml](../agent-setup/models.yaml), Heavy when the change is Risky. Resolve the id
with `orchestrator_capabilities`. An unavailable family:
the same tier in your own family, in a fresh context; the result line then says
"same-family review". With no route to any reviewer, report the blocker.

## Budget

- Default 3 rounds. Round 1 is full; later rounds check only changed code and open findings.
- Extend to 5 only for security, permissions, auth, data loss, or state and concurrency,
  while a blocker or should stays open with evidence, or when the user asks.
- Stop early when a round returns only nits. Declined nits and comment, doc or format-only
  fixes need no new round.
- One reviewer only. The reviewer starts no subagents or reviewers of its own.
- Keep a ledger: id, severity, outcome, usage if returned. Record only what was returned.

## 1. Scope

Run `git status --short`. Leave unrelated changes alone: no stash, no discard, no
inclusion. Limit the review to the change's paths when they separate cleanly; otherwise review the
whole working tree and say so in the brief.

Find the base after `git fetch origin`:

- PR: `gh pr view <n> --json baseRefName,headRefOid`. Check out the branch only if clean.
  Confirm `HEAD` is the PR head, or ahead only by this change. Base: `git merge-base HEAD
  origin/<baseRefName>`.
- Local: `git merge-base HEAD origin/<default-branch>`. No remote: a base the user names, or
  `HEAD` for uncommitted changes only.

The change is base to working tree in those paths, with untracked files. Use one diff
command for every round. State the intent and what is out of scope in 1–2 sentences. Run
the covering checks; send only code that passes them, and note missing or already-failing
checks in the brief.

## 2. Start the reviewer

T3: `delegate_task` every round (`role: "review"`, `mode: "async"`), with the model and
effort named. Save the `taskId`; a new `clientRequestId` per round. `childThreadId` is
storage, not the next target; reviews go through `delegate_task` only. Native: a subagent on
the reviewer's model, keeping its id.

Leave the scoped files untouched while the review runs. Wait for the result notice; no
polling, no second reviewer. A timeout, error or no reply is not approval: cancel, confirm
it stopped, restart with the ledger.

Round 1 brief (children get no history):

```
Review only. Do not edit, commit, push, comment on PRs, or start subagents.
Repo: <abs path> Base: <sha> Intent: <intent> Out of scope: <scope> Checks: <results>
See: git diff <base> [-- <paths>]; git status --short (read untracked).
Read surrounding code. Find bugs, broken callers, mismatch with intent.
Skip style unless it hides a bug. Hold to the smallest change. Flag code,
tests, or guards the intent does not need. Other paths, rare cases, small
perf, extra compat: nits.
blocker = intended case wrong. should = real bug callers will hit, in intent. nit = rest.
Reply:
VERDICT: APPROVE or CHANGES
S1 [blocker|should|nit] <file>:<line> <claim>. Fix: <suggestion> (stable ids)
```

## 3. Answer findings

Check each finding and its severity yourself. Another path, a rare case or a small cost is
a nit, whatever label it came with.

- Agree: the smallest fix. Prefer deleting or narrowing over a new lock, cache, helper or
  option. Fix the case that happened. Add one focused test that fails without the fix, if
  the intent needs it.
- Disagree: say why, with evidence (file:line, test, output).
- Out of scope or nit: decline in one line and list it as a follow-up.

Update the ledger. Re-run the checks and `git diff --shortstat <base>`. If review grew the
diff, cut first. Agree only with findings you believe.

## 4. Next round

Start one only if budget remains and a blocker or should is open, behaviour code changed, or
the last approval does not cover the current behaviour diff. A fresh `delegate_task` (or a
follow-up to the saved native id) with the round 1 brief, the ledger (`fixed:` /
`disagree:` / `declined:` + evidence), the same base diff, and the change since the last
round. Tell the reviewer: open ids and changed code only; mark each old id `resolved` or
`still open: <reason>`.

## 5. Stop

- **Agreed:** APPROVE on the current behaviour diff, no blocker or should open, no concern
  of your own.
- **Stuck:** an item stays disputed after two replies, or the budget ends. Show both sides in
  2–3 lines each. Under full-send, take the more conservative side (the smaller change, or
  the reviewer's fix when it guards the intended case) and list it under "Decided for you"
  (likewise under full-stop or a coordinator's brief); otherwise the user decides. Budget
  end is not approval.

Push during the loop only when full-send, full-stop or the user asked to push. The PR gets, above the
model line: `Reviewed with review-loop: <N> rounds with <model>. Verdict: approved` (add
`on <effort>` only if verified, and "same-family review" when it was).

Report: rounds, model, what the review changed, diff size before and after, fixed and
declined findings with reasons, usage if exposed (else say so), pushed or not.
