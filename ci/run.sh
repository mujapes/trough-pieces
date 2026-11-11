#!/bin/sh
# Rebuilds every piece on this machine and replays its recorded checks. The checks were recorded on a Pixel 7a; passing here says the
# descriptions and the C mean the same thing on a different processor and compiler. Each line of ci/pieces.txt: name, live source, entries.
set -eu
cd "$(dirname "$0")/.."
mkdir -p out
gcc -O2 -o out/vectors loader/vectors.c loader/piece.c
gcc -O2 -o out/certfuzz loader/certfuzz.c loader/piece.c
fail=0
while read -r name src entries; do ./build.sh "$name/reference.c" "out/$name.ref" $entries >/dev/null || { echo "BUILD FAILED $name reference"; fail=1; }; done < ci/pieces.txt
while read -r name src entries; do
  stem="out/$name.ref"
  if [ "$src" != reference.c ]; then ./build.sh "$name/$src" "out/$name.live" $entries >/dev/null && stem="out/$name.live" || { echo "BUILD FAILED $name $src"; fail=1; continue; }; fi
  for s in "out/$name.ref" "$stem"; do
    if ./out/vectors check "$s" "out/$name.piece" "out/$name.vectors" > out/check.txt 2>&1; then echo "ok   $s: $(tail -1 out/check.txt)"; else echo "FAIL $s: $(tail -1 out/check.txt)"; fail=1; fi
    [ "$s" = "$stem" ] && break
  done
done < ci/pieces.txt
echo "--- damaged certificates (each against an unreadable page)"
for c in leaf wiki root middle; do ./out/certfuzz out/cert.ref "out/cert-$c.fixture" "${FUZZ_ROUNDS:-3000000}" || { echo "FUZZ FAILED $c"; fail=1; }; done
exit $fail
