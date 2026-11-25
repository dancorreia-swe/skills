---
name: council
description: Gets a verdict from one strong model per provider in parallel and loops until they agree, for a review or for an open choice. Use when the user says "council", or when another skill calls for one (full-send's review of an M, L or Risky change, an ADR-level choice, a decision the docs leave open).
---

# Council

Adapted from [tstack](https://github.com/t3dotgg/tstack) (MIT, Theo Browne).

## Members and judge

The `panel` list in [models.yaml](../agent-setup/models.yaml) (the user's copy in
`~/.config/agent-setup/` replaces it): one strong model per provider, at high effort.
Members the user names win. A provider is available when its member's provider is enabled:
`orchestrator_capabilities` (`canRunChildTask: true`; resolve the ids there). full-send
counts them to pick its review: M changes get a council only with 3 or more.

A member that turns out unavailable (`model_unavailable`, a usage limit, a disabled
provider) shows as `unavailable` in the results, and you go on with the rest, keeping the
provider mix as it is. With fewer than two providers left, run a **same-family council**:
two members on your own family's Heavy model, each in a fresh context with the same brief,
and every result labelled "same-family". It is weaker evidence than a mixed panel: it counts
as one provider (M changes stay on `review-loop`), and a lasting choice it agrees on is
logged with `council same-family <tally>`.

**You are the judge**: you check each result against the code and decide what to fix. The
judge runs Heavy (models.yaml); the members run their panel entries. A builder whose review
will be a council is launched Heavy for that reason (`autopilot`). Judging on a lower tier
anyway (a thread the user started), add `Judge: <model>` to the results.

## Before a review

Address open PR comments, fix known issues and run the relevant checks first, so the council
sees the current implementation. When the user is discarding the implementation to explore
new ideas, skip fixes to code being replaced.

## Run it

1. Write one brief: the request, the relevant context, and what each member returns. A
   review: findings by severity and a score out of 10. A choice: the pick, why, and the risk
   that would change it, each member blind to your preferred answer.
2. Start one delegate per member, all in one message, async (T3: parallel `delegate_task`,
   `role` `review` or `research`, `mode` `async`, each with its member's
   `target.providerInstanceId`, `model` and effort). Members work read-only.
3. **Act as results arrive.** Check each result against the code at once and decide what to
   fix while the others run. Leave files alone while a member still reviews the same
   checkout. A member the user marks non-blocking is not waited for; a late result is
   feedback, and its score goes unrecorded.
4. Summarise the useful findings, the disagreements and the next steps.
5. Agreeing with the recommendations: make the changes and start a fresh round. Continue
   until every member is satisfied, within 3 rounds (5 for security, permissions, auth, data
   loss, or state and concurrency, while a blocker stays open with evidence). Each full pass
   is one round; a fresh review after fixes starts the next.
6. **Stuck** (the budget ends, or a point stays disputed after two replies): a review takes
   the more conservative side and lists it under "Decided for you"; a choice is split
   (`full-send`, "Deciding" step 4).

Fight scope creep: repeated reviews tend to grow the change one cheap fix at a time. Keep
the change at the size the goal needs, and decline the rest with a written reason.

## Results

A review that ends in a PR: put this in the PR description, before the model and harness
line, and edit the description rather than posting a comment.

```markdown
## Council review

Rounds: 2

| Delegate | Round 1 | Round 2 |
| --- | --- | --- |
| Claude Opus | 7/10 | 9/10 |
| GPT Sol | 8/10 | 10/10 |
```

Write `no score` or `unavailable` where that is what happened; record only scores members
gave. With no PR, put the same table in the final reply.

A choice: the tally and each member's pick go to the decisions file (`full-send`,
"Deciding"); the members' reasoning stays in their reports.
