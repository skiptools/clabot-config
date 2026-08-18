#!/usr/bin/env bash
#
# Validates that a pull request does nothing more than add its own author to the
# "contributors" list of the .clabot file.
#
# Usage: check-self-signup.sh <base-clabot> <head-clabot> <author-login>
#
# On success the added username is printed to stdout and the script exits 0.
# On failure the reason is printed to stderr and the script exits 1.

set -euo pipefail

base_file=${1:?base .clabot file required}
head_file=${2:?head .clabot file required}
author=${3:?author login required}

sentinel="ADD_NEW_GITHUB_USERNAMES_ABOVE_THIS_LINE"

fail() { echo "$*" >&2; exit 1; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

jq -e . "$base_file" >/dev/null 2>&1 || fail "the .clabot file in the base branch is not valid JSON"
jq -e . "$head_file" >/dev/null 2>&1 || fail "the .clabot file is not valid JSON"

# nothing outside of the contributors list may be touched
jq -e -n --slurpfile b "$base_file" --slurpfile h "$head_file" \
  '($b[0] | del(.contributors)) == ($h[0] | del(.contributors))' >/dev/null \
  || fail "the pull request modifies .clabot fields other than \`contributors\`"

for f in "$base_file" "$head_file"; do
  jq -e '.contributors | type == "array"' "$f" >/dev/null \
    || fail "\`contributors\` must be a JSON array"
  jq -e '.contributors | map(type == "string") | all' "$f" >/dev/null \
    || fail "\`contributors\` must contain only strings"
done

# locate the single entry that was inserted, preserving the order of the rest
added=$(jq -r -n --slurpfile b "$base_file" --slurpfile h "$head_file" '
  $b[0].contributors as $base
  | $h[0].contributors as $head
  | if ($head | length) != (($base | length) + 1) then ""
    else
      ( [range(0; $head | length)]
        | map(. as $i | select(($head[0:$i] == $base[0:$i]) and ($head[$i+1:] == $base[$i:]))) ) as $idx
      | if ($idx | length) == 0 then "" else $head[$idx[0]] end
    end')

[ -n "$added" ] \
  || fail "the pull request must add exactly one username to \`contributors\` and leave every other entry unchanged"

[ "$(lower "$added")" = "$(lower "$author")" ] \
  || fail "the pull request adds \`$added\` but was opened by \`$author\`; contributors may only sign the CLA for themselves"

jq -e -n --slurpfile b "$base_file" --arg author "$(lower "$author")" \
  '$b[0].contributors | map(ascii_downcase) | index($author) | not' >/dev/null \
  || fail "\`$author\` is already listed in \`contributors\`"

if [ "$(jq -r '.contributors[-1]' "$base_file")" = "$sentinel" ] \
   && [ "$(jq -r '.contributors[-1]' "$head_file")" != "$sentinel" ]; then
  fail "new usernames must be added above the \`$sentinel\` marker"
fi

printf '%s\n' "$added"
