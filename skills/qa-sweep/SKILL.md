---
name: qa-sweep
description: QA in a running app, device or browser, plus staging sweeps that file defects as agent-ready issues. Use when acceptance needs checking on a simulator, emulator, browser or staging, when the user asks for a QA sweep (one-off or recurring), or when full-send needs UI proof.
---

# QA sweep

QA runs as its own helper on the Mid tier (Light for re-checks; models.yaml in
`agent-setup`), so the device loop stays out of the coordinator's and the builder's context.
Start it with the model and effort named: your native subagent, or `delegate_task` with
`role` `test` (pass the device's `hostId` and `id`). The helper gets the acceptance criteria
and the device or URL, and returns pass/fail per criterion with evidence paths.

## Device loops

- Read the accessibility tree before any screenshot; take a screenshot only when the tree
  cannot answer the question, cropped to the region needed, at most 1280 px wide.
- One shell call per step: the action, its settle, and the next read together. Settle on a
  condition: the device tool's own wait command (`agent-device help` lists them in T3), a
  `curl` or port check for a server, `adb shell` state for Android. A fixed pause is the
  fallback when no condition exists, at most 2 s, inside that same call.
- A server the test needs starts with the shell's background option and is awaited by
  condition (T3: `t3_background_wait` on its task id before the turn ends), not by a series
  of `sleep` calls.
- T3: `device_open` with the `hostId` and device `id` from the brief, then drive the
  returned `agent-device` command.

## Sweep on staging

1. **Verify** on staging with `playwright-cli`. File one issue per defect with Area,
   Severity rationale, How established, Steps to reproduce, Expected, Actual, Evidence,
   Suggested direction and an "Agent brief"; label it `ready-for-agent`. Comment on an open
   issue instead of filing a duplicate.
2. **Fix:** the defects join the frontier of the next `autopilot` run, or each gets a
   builder running `full-send` / `full-stop`.
3. **Re-verify:** when a fixing PR merges and deploys to staging, the coordinator (or the
   builder, with no coordinator) starts a Light QA pass; it confirms the fix and closes the
   issue, or reopens it with evidence.
4. **Recurring** (when the user asks for one): schedule step 1 as a Light QA run, weekdays
   at 07:00 unless the user says otherwise. List the scheduled tasks first and update one
   already there rather than duplicating it (`list_scheduled_tasks`, then
   `schedule_task` with `schedule` `{type:"fixed_time", timeOfDay:"07:00",
   weekdays:[1,2,3,4,5]}` and `freshSession:true`). Report the next run time. Its prompt
   is self-contained: the staging URL, the flows to cover,
   the issue format above, and "file new defects only; comment on an open issue instead of
   filing a duplicate". It files issues and stops; fixing is autopilot's or a coordinator's
   call.
