#!/bin/sh
# Put a piece's previous implementation back. It goes through promote.sh, so it must pass today's tests:
# an implementation that speaks an older state layout than the description now requires is refused there,
# and the answer is a fix that moves forward, not a step back.
#   rollback.sh <piece>
set -eu
cd "$(dirname "$0")"
P=$1
NOW=$(cat "out/$P.live" 2>/dev/null || echo "")
PREV=$(awk -v p="$P" -v now="$NOW" '$2==p && $3!=now {v=$3} END{print v}' out/history.log 2>/dev/null)
[ -n "$PREV" ] || { echo "no earlier implementation of $P in the history" >&2; exit 1; }
echo "rolling $P back from ${NOW:-unknown} to $PREV"
exec ./promote.sh "$P" "$PREV"
