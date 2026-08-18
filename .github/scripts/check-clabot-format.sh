#!/usr/bin/env bash
#
# Checks that a .clabot file is valid, canonically formatted JSON.
#
# Usage: check-clabot-format.sh <clabot-file>
#
# Exits 0 when the file is well formed, otherwise prints the reason on stderr
# and exits 1.

set -euo pipefail

file=${1:?a .clabot file is required}

if ! jq -e . "$file" >/dev/null 2>&1; then
  echo "the .clabot file is not valid JSON:" >&2
  jq . "$file" >/dev/null 2>&1 || jq . "$file" 2>&1 >/dev/null | sed 's/^/  /' >&2
  exit 1
fi

if ! diff -u --label "expected" --label "actual" <(jq --indent 2 . "$file") "$file" >/dev/null; then
  {
    echo "the .clabot file is valid JSON but is not formatted canonically."
    echo "It must match the output of \`jq --indent 2 . .clabot\`: two-space indentation,"
    echo "one username per line, and a trailing newline. Difference:"
    diff -u --label expected --label actual <(jq --indent 2 . "$file") "$file" | sed 's/^/  /'
  } >&2
  exit 1
fi
