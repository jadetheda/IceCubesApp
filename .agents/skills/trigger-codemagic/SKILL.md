---
name: trigger-codemagic
description: >-
  Use this skill when the user asks to trigger, start, run, or monitor a Codemagic build.
---

# Trigger & Monitor Codemagic Build

This skill provides the capability to trigger and monitor Codemagic CI/CD builds for this repository.

## Prerequisites

Before triggering a build, ensure you have the required credentials. The scripts expect them in the `.env` file at the root of the project.
- `CODEMAGIC_TOKEN`: The user's Codemagic personal access token.
- `CODEMAGIC_APP_ID`: The Codemagic application ID for this project.

## 1. Triggering a Build

1. Verify the current branch is pushed to GitHub.
2. Run the trigger script:
   `./.agents/skills/trigger-codemagic/scripts/trigger.sh <workflow_id> <branch>`
   *(Defaults to `ios-unsigned-build` and `main`)*
3. Read the JSON output. If successful, it will return a `buildId`.
4. Report the `buildId` back to the user to confirm the build has started.

## 2. Monitoring a Build (Iterative CI/CD)

If the user wants you to monitor the build, or iterate if it fails:

1. Use the status script to check on the build:
   `./.agents/skills/trigger-codemagic/scripts/status.sh <build_id>`
2. **Do not run a blocking `while` loop or `sleep` in the terminal.** Instead, use your `schedule` tool to set a one-shot timer (e.g., 30 or 60 seconds) or a recurring cron job to notify yourself to check the status script again.
3. If the status is `finished`, notify the user of success.
4. If the status is `failed`, the status script will attempt to extract which step failed. You can then investigate the failure, push a fix to GitHub, and trigger a new build using the steps above.

## 3. Canceling a Build

If you need to stop a running or queued build:
1. Run the cancel script:
   `./.agents/skills/trigger-codemagic/scripts/cancel.sh <build_id>`
