#!/usr/bin/env bash
#
# Reconciles the organisation-wide cla-bot check with the fact that this
# repository is where the CLA gets signed in the first place:
#
#   1. cla-bot is installed across the whole skiptools organisation and has no
#      per-repository opt-out, so it flags every pull request opened here by a
#      contributor who has not signed yet -- which is all of them. Its
#      `verification/cla-signed` commit status is overridden with a success, and
#      the comment it leaves is removed.
#
#   2. A pull request whose only change is adding its own author to the
#      `contributors` list of a still-valid .clabot file is approved and merged.
#
# Driven by .github/workflows/cla.yml; expects GH_TOKEN, REPO, EVENT_NAME and
# the event-specific PR_NUMBER / DISPATCH_PR / STATUS_SHA in the environment.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

status_context="verification/cla-signed"
bot_login="cla-bot[bot]"

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

process() {
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
  if [ "$(jq -r .draft <<<"$pull")" = "true" ]; then
    echo "#$pr is a draft"
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
  if [ "$files" != ".clabot" ]; then
    echo "#$pr changes $(tr "\\n" " " <<<"${files:-nothing}")rather than just .clabot; leaving it for a maintainer"
    return 0
  fi

  fetch_clabot "$merge_base" "$work/base.clabot"
  fetch_clabot "$head_sha" "$work/head.clabot"

  if ! added=$("$here/check-self-signup.sh" \
    "$work/base.clabot" "$work/head.clabot" "$author" 2>"$work/reason"); then
    echo "#$pr needs a maintainer: $(cat "$work/reason")"
    return 0
  fi

  echo "#$pr signs the CLA for its own author ($added); approving and merging"
  gh api -X POST "repos/$REPO/pulls/$pr/reviews" -f event=APPROVE \
    -f body="Automatically approved: this pull request adds \`$added\` to the contributor list and nothing else, and it was opened by that user." \
    >/dev/null || echo "::warning::could not approve #$pr"

  gh api -X PUT "repos/$REPO/pulls/$pr/merge" -f sha="$head_sha" -f merge_method=merge >/dev/null
  echo "merged #$pr"
}

case "$EVENT_NAME" in
  pull_request_target) pulls=${PR_NUMBER:-} ;;
  workflow_dispatch) pulls=${DISPATCH_PR:-} ;;
  status) pulls=$(gh api "repos/$REPO/commits/$STATUS_SHA/pulls" --jq '.[].number') ;;
  *) echo "unsupported event: $EVENT_NAME" >&2 && exit 1 ;;
esac

if [ -z "${pulls//[[:space:]]/}" ]; then
  echo "no pull requests to process"
  exit 0
fi

for pull in $pulls; do
  echo "::group::pull request #$pull"
  process "$pull" || echo "::warning::could not process #$pull"
  echo "::endgroup::"
done
