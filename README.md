This is a repository for Skip contributor licence agreements (CLAs) handling.

## Add user

If you accept the Skip
[CLA](Contributor-License-Agreement.md),
***please [add your GitHub username to the `.clabot` file](https://github.com/skiptools/clabot-config/edit/main/.clabot)*** and create a PR in this repo.

A PR that does exactly that is approved and merged automatically, so there is no need to wait for a Skip developer. To qualify it has to satisfy all three of these rules:

1. **The file stays valid, canonically formatted JSON.** It must match the output of `jq --indent 2 . .clabot` — two-space indentation, one username per line, trailing newline. Editing the file through GitHub's web editor keeps this formatting automatically.
2. **Exactly one username is added, directly above the `ADD_NEW_GITHUB_USERNAMES_ABOVE_THIS_LINE` marker.** That marker stays the last entry in the list. No other entry may be added, removed or reordered, and no other part of the file may change.
3. **The added username is your own** — the GitHub account that opened the PR. Nobody can sign the CLA on someone else's behalf.

If a PR edits `.clabot` and breaks any of these rules, the `Validate` check fails and says which rule was broken. Fix the PR, or ask a Skip developer to review and merge it by hand.

PRs that leave `.clabot` untouched are not subject to these rules.

## The cla-bot check in this repository

The CLAs are handled by cla-bot, which checks for the presence of a contributor's name in the `.clabot` file. On other `skiptools` repositories a `@cla-bot recheck` comment re-triggers it after a PR here is merged.

cla-bot is installed across the whole `skiptools` organisation and has no per-repository opt-out, so it also flags every PR opened *here* — even though signing the CLA is the very thing these PRs do ([#29](https://github.com/skiptools/clabot-config/issues/29)). The [`Validate` workflow](.github/workflows/validate.yml) exempts this repository from that check: it overrides the `verification/cla-signed` status with a success and removes the comment cla-bot leaves behind. Contributors should not see a CLA failure here.
