---
name: takeover
description: Continues existing work as its new owner: a PR, a branch, an agent thread, or an autopilot run. Use when the user or a predecessor says "take over", or when a prompt points you at a run card or handoff file.
---

# Takeover

Adapted from [tstack](https://github.com/t3dotgg/tstack) (MIT, Theo Browne).

Take responsibility for finishing the original goal while keeping the original
contributors' credit. Defend an implementation on its merits, not because another agent
already built it.

## A run card or handoff file

You are the new owner of a coordinator run (autopilot) or a long task.

1. Read the file in full, starting with **START HERE**, then its decisions file
   (`full-send`, "Deciding"). Preserve existing uncommitted work.
2. Rebuild live state from the sources the file names rather than trusting it alone: open
   PRs and their checks, the tickets, the builder threads (`autopilot`'s host
   map, "List existing").
3. Take over the host state the file lists: the heartbeat's scheduled task (point its prompt
   at your thread), PR watches, run ids.
4. Continue the same skill from where the file says (a run: `autopilot` §3's reconcile
   first, then §2), and write your thread id into the file.

## Writing a handoff file

For a predecessor handing work over (an autopilot run uses its run card instead):
`~/.<project>-handoffs/<topic>.md`, never the session scratchpad. Sections: the original
brief verbatim; standing decisions and the decisions file path; host state (run ids, thread
links, task ids); repo state (branches, PRs, uncommitted work); environments (URLs,
credential *locations*, never values); open items for the user; **START HERE**, the next
3–5 concrete steps. The successor's prompt: "Use `takeover`: you are taking over <topic>.
Read <file> first."

## A PR, branch or thread

Read the source PR, branch or thread, including review findings and the user's later
corrections. Resolve the handoff to the actual code and current head, and account for
uncommitted work. The handoff is context; the code is the evidence.

For a replacement PR, import the original commits onto a new branch and add your fixes
separately. Honour an explicitly requested in-place or stacked continuation instead. Leave
unrelated work alone, and change the original PR only with authorization.

Preserve Git authorship and existing co-author trailers. Credit the original contributors
in the PR description and link the original PR. If the work will be squashed, keep human
author and co-author credit in the merge commit too, using verified identities, not guessed
emails. Model attribution is no substitute for contributor credit.

Use `modernize` to update the continuation against its intended base and current
architecture. Its REWORK verdict is yours to do under the grant you have; CLOSE goes in the
report. Rework what finishing the same goal needs, not unrelated features. Simplify
without dropping intended behaviour or surfaces. Recheck the source PR too: it may have
improved while you worked.

Independently verify the original failure and realistic workflows (full-send, "Proof").
State what remains unverified.

When the finish includes a PR, carry on under the grant you were given: `full-send` or
`full-stop`, or otherwise the `pr` skill to file it and `babysit-pr` after. Use
`leaving-pr-comments` for replies. Merge or close the original PR only when authorized.

Report what you inherited, what you changed, how you verified it, how credit was preserved,
and any remaining decision.
