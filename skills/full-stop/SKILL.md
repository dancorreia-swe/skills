---
name: full-stop
description: Same as full-send, but stops with the PR ready for the user to merge. Use when the user says "full stop" (even a closing "Full stop." that reads like emphasis), or when an autopilot or coordinator brief says to use it.
---

# Full Stop

Adapted from [tstack](https://github.com/t3dotgg/tstack) (MIT, Theo Browne).

Do the work of `full-send` and stop with the PR ready for the user to merge. Read
[full-send](../full-send/SKILL.md) and follow its steps, proof rules, review, babysitting,
"Deciding" and "Context", including its testing permission. Its merge permission does not
apply. The overrides below take precedence.

## No merging

You may commit, push, rebase, fix conflicts and use `--force-with-lease` on this task's
branch. Merging, auto-merge, a merge queue, pushing to the default branch and bypassing
branch protection stay with the user, and so does delegating any of those.

Disable existing auto-merge and take the PR out of any merge queue before work begins; check
again before each push. Report these changes. If you cannot prevent an automatic merge,
report that before going on.

## Stop at the gate

full-send's merge gate is the readiness check; its merge step becomes this handoff. Proof
and review cover the final diff; recheck behaviour changes and meaningful conflict fixes
before handing off.

Fetch the target branch and check the live PR's head, base, checks, reviews and
mergeability. Confirm it is open, not a draft, and not set to merge without the user. If
someone else merged it, report that instead.

- **Ready to merge:** the merge gate passes. Leave the PR open and unmerged.
- **Waiting for required approval:** only human approval remains, and that is the actual
  blocker. Report it as `ready`.
- **Blocked:** what prevents readiness, what you tried, what is needed (full-send,
  "Deciding").

Unwatch the PR before the handoff or a question. Report the PR link, final head, verdict,
proof, review outcome and remaining risks, and say the PR is still open and unmerged. A
coordinator's builder sends its one line back as in full-send's "Report", with `ready`.
