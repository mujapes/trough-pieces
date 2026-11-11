#!/bin/sh
# Make one built implementation of a piece the live one. Look before you leap: the candidate must replay the
# piece's recorded checks here first (and pass the piece's own test program, if it has one); only then is it
# copied into place, where the running app notices it, replays the checks again inside its own process, and
# swaps to it without any rebuild.
#   promote.sh <piece> <variant>      e.g. promote.sh sound-measures asm
set -eu
cd "$(dirname "$0")"
P=$1 V=$2
[ -f "out/$P.$V.bin" ] && [ -f "out/$P.$V.entries" ] || { echo "no such build: out/$P.$V" >&2; exit 1; }
[ -f "out/$P.piece" ] && [ -f "out/$P.vectors" ] || { echo "$P has no description or no recorded checks" >&2; exit 1; }
./out/vectors check "out/$P.$V" "out/$P.piece" "out/$P.vectors" > "out/$P.$V.check" 2>&1 || { echo "candidate FAILED its recorded checks; nothing changed" >&2; cat "out/$P.$V.check" >&2; exit 1; }
if [ -x "out/test-$P" ]; then "./out/test-$P" "out/$P.$V" >> "out/$P.$V.check" 2>&1 || { echo "candidate FAILED its tests; nothing changed" >&2; cat "out/$P.$V.check" >&2; exit 1; }; fi
# The code and its entry list are two files and cannot be replaced in one step. The running app once read the new list with the old
# code and jumped into the middle of it: Trough died (2026-11-11 16:31). So the pair carries a seal: the fingerprints of exactly the
# code and the list that belong together. The seal is removed first and written last; the app loads nothing whose files do not match it.
rm -f "out/$P.pair"
cp "out/$P.$V.entries" "out/$P.entries.tmp" && mv "out/$P.entries.tmp" "out/$P.entries"
cp "out/$P.$V.bin" "out/$P.bin.tmp" && mv "out/$P.bin.tmp" "out/$P.bin"
printf '%s %s\n' "$(sha256sum < "out/$P.bin" | cut -d' ' -f1)" "$(sha256sum < "out/$P.entries" | cut -d' ' -f1)" > "out/$P.pair.tmp" && mv "out/$P.pair.tmp" "out/$P.pair"
echo "$V" > "out/$P.live"
echo "$(date +%Y-%m-%dT%H:%M:%S) $P $V $(wc -c < "out/$P.bin") bytes" >> out/history.log
echo "promoted $P to $V ($(wc -c < "out/$P.bin") bytes)"
# Show it: every promotion lands on the home screen's progress card without anyone remembering to.
[ -x /data/user/0/t.t/files/home/.local/bin/trough-show ] && /data/user/0/t.t/files/home/.local/bin/trough-show "Promoted $P ($V): passed its recorded checks" >/dev/null 2>&1 || true
