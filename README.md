This is a repository for Skip contributor licence agreements (CLAs) handling.

## Add user

If you accept the Skip
[CLA](Contributor-License-Agreement.md),
***please [add your GitHub username to the `.clabot` file](https://github.com/skiptools/clabot-config/edit/main/.clabot)*** and create a PR in this repo.

Add your username on its own line above the `ADD_NEW_GITHUB_USERNAMES_ABOVE_THIS_LINE` marker, and change nothing else. A PR that adds only its own author's username to a valid `.clabot` file is approved and merged automatically, so there is no need to wait for a Skip developer.

Anything else — adding someone else's username, adding more than one name, editing another part of the file, or touching another file — is left for a Skip developer to review and merge by hand.

The CLAs are handled by cla-bot, which will check for the presence of the contributor's name in the `.clabot` file. When the PR is merged, the cla-bot can be triggered again with a `@cla-bot recheck` comment.

## The cla-bot check in this repository

cla-bot is installed across the whole `skiptools` organisation and has no per-repository opt-out, so it flags every PR opened here — signing the CLA is the very thing these PRs do ([#29](https://github.com/skiptools/clabot-config/issues/29)). The [CLA workflow](.github/workflows/cla.yml) exempts this repository from that check: it overrides the `verification/cla-signed` status with a success and removes the comment cla-bot leaves behind. Contributors should not see a failing check here.
