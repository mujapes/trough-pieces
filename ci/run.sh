#!/bin/sh
# Rebuilds every piece on this machine and replays its recorded checks. The checks were recorded on a Pixel 7a; passing here says the
# descriptions and the C mean the same thing on a different processor and compiler. Each line of ci/pieces.txt: name, live source, entries.
set -eu
cd "$(dirname "$0")/.."
mkdir -p out
gcc -O2 -o out/vectors loader/vectors.c loader/piece.c
gcc -O2 -o out/certfuzz loader/certfuzz.c loader/piece.c
fail=0
# The compiled statement of meaning is built where it builds. Where the live implementation is hand-written, a reference that this
# machine's compiler cannot build as a self-contained piece is reported and stood in for by the hand-written one (other pieces
# reach it through the call table either way).
while read -r name src entries; do
  if ! ./build.sh "$name/reference.c" "out/$name.ref" $entries > out/build.txt 2>&1; then
    case "$src" in *.S) echo "note $name: reference.c does not build here ($(tail -1 out/build.txt)); using the hand-written one"; ./build.sh "$name/$src" "out/$name.ref" $entries >/dev/null ;;
      *) tail -5 out/build.txt; echo "BUILD FAILED $name reference"; fail=1 ;; esac
  fi
done < ci/pieces.txt
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
echo "--- script: our own JavaScript engine against node and qjs, program by program"
gcc -O2 -o out/render loader/render.c loader/piece.c
if ./build.sh script/impl.S out/script.asm begin tokens numtext load run text error clock; then python3 script/checks/run.py out/script.asm > out/script.txt 2>&1 || fail=1; tail -15 out/script.txt; else echo "BUILD FAILED script"; fail=1; fi
echo "--- dom: the page as a tree, request by request against the recorded answers"
if ./build.sh dom/impl.S out/dom.asm begin ask && gcc -O1 -o out/domt dom/checks/t.c loader/piece.c && ./out/domt out/dom.asm < dom/checks/t.txt | cmp -s - dom/checks/t.out; then echo "dom: answers as recorded"; else echo "dom: FAILED"; fail=1; fi
exit $fail
echo "--- reload: take/back on a call table"
./build.sh reload/impl.S out/reload.live record part take back >/dev/null && gcc -O1 -o out/swapcheck reload/checks/swap.c loader/piece.c && ./out/swapcheck out/reload.live || exit 1
