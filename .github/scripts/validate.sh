#!/usr/bin/env bash
#
# Every check this repository performs, driven by .github/workflows/validate.yml.
#
# On a push, the .clabot file in the tree is checked for well-formedness.
#
# On a pull request, the proposed .clabot file is held to all three rules in
# check-self-signup.sh, and the check fails if it breaks any of them. A pull
# request that satisfies them and touches nothing else is approved and merged.
#
# cla-bot is installed across the whole skiptools organisation and has no
# per-repository opt-out, so it flags every pull request opened here by a
# contributor who has not signed yet -- which is all of them. Its
# `verification/cla-signed` commit status is therefore overridden with a
# success, and the comment it leaves is removed.
#
# Expects GH_TOKEN, REPO, DEFAULT_BRANCH, EVENT_NAME and the event-specific
# PR_NUMBER / DISPATCH_PR / STATUS_SHA in the environment.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

status_context="verification/cla-signed"
bot_login="cla-bot[bot]"

# Reports a fatal problem with a proposed .clabot file, on the job log, as an
# annotation against the file, and in the run summary.
reject() {
  local pr=$1 reason=$2
  echo "::error file=.clabot::$reason"
  {
    echo "### :x: \`.clabot\` cannot be accepted"
    echo
    echo "$reason"
    echo
    echo "Add your own GitHub username on its own line directly above the"
    echo "\`ADD_NEW_GITHUB_USERNAMES_ABOVE_THIS_LINE\` marker, change nothing else, and keep the"
    echo "file's existing formatting. See [the README](../blob/$DEFAULT_BRANCH/README.md) for details."
  } >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
  echo "#$pr rejected: $reason"
}

# Overrides cla-bot's verdict on a pull request and removes its comment.
clear_cla_complaint() {
  local pr=$1 head_sha=$2 state

  state=$(gh api "repos/$REPO/commits/$head_sha/status" \
    --jq ".statuses[] | select(.context == \"$status_context\") | .state" | tail -n1)
  if [ "$state" != "success" ]; then
    gh api -X POST "repos/$REPO/statuses/$head_sha" \
      -f state=success \
      -f context="$status_context" \
      -f description="Not required: this repository is where the CLA is signed" \
      -f target_url="${RUN_URL:-}" >/dev/null
    echo "set $status_context to success for $head_sha"
  fi

  gh api --paginate "repos/$REPO/issues/$pr/comments" \
    --jq ".[] | select(.user.login == \"$bot_login\") | .id" |
    while read -r id; do
      gh api -X DELETE "repos/$REPO/issues/comments/$id" && echo "removed $bot_login comment $id"
    done
}

# Writes the .clabot file at the given revision to the given path.
fetch_clabot() {
  gh api "repos/$REPO/contents/.clabot?ref=$1" --jq .content | base64 -d >"$2"
}

# Validates one pull request, and merges it when it is a clean self-signup.
# Returns non-zero when the proposed .clabot file breaks any of the rules.
validate_pull_request() {
  local pr=$1 pull author head_sha base_ref comparison files merge_base added

  pull=$(gh api "repos/$REPO/pulls/$pr")
  author=$(jq -r .user.login <<<"$pull")
  head_sha=$(jq -r .head.sha <<<"$pull")
  base_ref=$(jq -r .base.ref <<<"$pull")

  clear_cla_complaint "$pr" "$head_sha"

  if [ "$(jq -r .state <<<"$pull")" != "open" ]; then
    echo "#$pr is no longer open"
    return 0
  fi
  if [ "$base_ref" != "$DEFAULT_BRANCH" ]; then
    echo "#$pr targets $base_ref rather than $DEFAULT_BRANCH"
    return 0
  fi

  # the merge base is what GitHub diffs the pull request against
  comparison=$(gh api "repos/$REPO/compare/$base_ref...$head_sha")
  merge_base=$(jq -r .merge_base_commit.sha <<<"$comparison")
  files=$(jq -r '.files[].filename' <<<"$comparison")

  if ! grep -qx '\.clabot' <<<"$files"; then
    echo "#$pr leaves .clabot alone; nothing to validate"
    return 0
  fi

  fetch_clabot "$merge_base" "$work/base.clabot"
  fetch_clabot "$head_sha" "$work/head.clabot"

  if ! added=$("$here/check-self-signup.sh" \
    "$work/base.clabot" "$work/head.clabot" "$author" 2>"$work/reason"); then
    reject "$pr" "$(cat "$work/reason")"
    return 1
  fi

  echo "#$pr adds \`$added\` for its own author"

  if [ "$files" != ".clabot" ]; then
    echo "#$pr also changes $(tr '\n' ' ' <<<"$files"); leaving the merge to a maintainer"
    return 0
  fi
  if [ "$(jq -r .draft <<<"$pull")" = "true" ]; then
    echo "#$pr is a draft; leaving the merge until it is ready"
    return 0
  fi

  echo "approving and merging #$pr"
  gh api -X POST "repos/$REPO/pulls/$pr/reviews" -f event=APPROVE \
    -f body="Automatically approved: this pull request adds \`$added\` to the contributor list and nothing else, and it was opened by that user." \
    >/dev/null || echo "::warning::could not approve #$pr"

  gh api -X PUT "repos/$REPO/pulls/$pr/merge" -f sha="$head_sha" -f merge_method=merge >/dev/null
  echo "merged #$pr"
}

case "$EVENT_NAME" in
  push)
    echo "checking the .clabot file on $GITHUB_REF_NAME"
    "$here/check-clabot-format.sh" .clabot
    echo ".clabot is well formed"
    ;;

  # cla-bot may post its verdict after the pull_request_target run has already
  # finished, so overriding it again here is the only work this event needs
  status)
    for pr in $(gh api "repos/$REPO/commits/$STATUS_SHA/pulls" --jq '.[].number'); do
      clear_cla_complaint "$pr" "$STATUS_SHA"
    done
    ;;

  pull_request_target | workflow_dispatch)
    pr=${PR_NUMBER:-${DISPATCH_PR:-}}
    [ -n "$pr" ] || { echo "no pull request to validate" >&2; exit 1; }
    validate_pull_request "$pr"
    ;;

  *)
    echo "unsupported event: $EVENT_NAME" >&2
    exit 1
    ;;
esac
