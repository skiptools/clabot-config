This is a repository for Skip contributor licence agreements (CLAs) handling.

## Add user

If you accept the Skip
[CLA](Contributor-License-Agreement.md),
***please [add your GitHub username to the `.clabot` file](https://github.com/skiptools/clabot-config/edit/main/.clabot)*** and create a PR in this repo.

(Note that when you file the PR signing the CLA, [Clabot will complain that you haven't signed the CLA yet](https://github.com/skiptools/clabot-config/issues/29)! But you can ignore that failure. A Skip developer will override the failure and merge the PR.)

The CLAs are handled by cla-bot, which will check for the presence of the contributors name in the `.clabot` file. When the PR is merged, the cla-bot can be triggered again with a `@cla-bot recheck` comment.
