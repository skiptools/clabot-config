#!/usr/bin/env bash
#
# Checks that a pull request does nothing to the .clabot file beyond adding its
# own author to the end of the `contributors` list:
#
#   1. the proposed file is valid, canonically formatted JSON
#   2. it adds exactly one username, directly above the final list entry
#   3. that username belongs to the user who opened the pull request
#
# Usage: check-self-signup.sh <base-clabot> <head-clabot> <author-login>
#
# On success the added username is printed on stdout and the script exits 0.
# On failure the reason is printed on stderr and the script exits 1.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

base_file=${1:?base .clabot file required}
head_file=${2:?head .clabot file required}
author=${3:?author login required}

sentinel="ADD_NEW_GITHUB_USERNAMES_ABOVE_THIS_LINE"

fail() { echo "$*" >&2; exit 1; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# 1. valid, canonically formatted JSON
"$here/check-clabot-format.sh" "$head_file" || exit 1

jq -e . "$base_file" >/dev/null 2>&1 || fail "the .clabot file on the base branch is not valid JSON"

# nothing outside of the contributors list may be touched
jq -e -n --slurpfile b "$base_file" --slurpfile h "$head_file" \
  '($b[0] | del(.contributors)) == ($h[0] | del(.contributors))' >/dev/null ||
  fail "the pull request modifies .clabot fields other than \`contributors\`"

for file in "$base_file" "$head_file"; do
  jq -e '.contributors | type == "array"' "$file" >/dev/null ||
    fail "\`contributors\` must be a JSON array"
  jq -e '.contributors | map(type == "string") | all' "$file" >/dev/null ||
    fail "\`contributors\` must contain only strings"
  jq -e '.contributors | length > 0' "$file" >/dev/null ||
    fail "\`contributors\` must not be empty"
done

# 2. exactly one username, inserted directly above the final entry
added=$(jq -r -n --slurpfile b "$base_file" --slurpfile h "$head_file" '
  $b[0].contributors as $base
  | $h[0].contributors as $head
  | ($base | length) as $n
  | if ($head | length) != $n + 1 then ""
    elif ($head[0:$n - 1] == $base[0:$n - 1]) and ($head[$n] == $base[$n - 1])
    then $head[$n - 1]
    else ""
    end')

if [ -z "$added" ]; then
  if [ "$(jq -r '.contributors[-1]' "$head_file")" != "$sentinel" ]; then
    fail "the new username must be added directly above the \`$sentinel\` marker, which has to stay the last entry"
  fi
  fail "the pull request must add exactly one username to \`contributors\`, directly above the \`$sentinel\` marker, leaving every other entry unchanged"
fi

[ "$added" != "$sentinel" ] || fail "\`$sentinel\` is a marker, not a username"

# 3. the added username is the pull request's own author
[ "$(lower "$added")" = "$(lower "$author")" ] ||
  fail "the pull request adds \`$added\` but was opened by \`$author\`; contributors may only sign the CLA for themselves"

jq -e -n --slurpfile b "$base_file" --arg author "$(lower "$author")" \
  '$b[0].contributors | map(ascii_downcase) | index($author) | not' >/dev/null ||
  fail "\`$author\` is already listed in \`contributors\`"

printf '%s\n' "$added"
