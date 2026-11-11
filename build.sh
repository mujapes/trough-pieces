#!/bin/sh
# Turn one implementation source into a loadable blob: flat machine code (plus its constants) and the
# offsets of its entries.
#   build.sh <source .S or .c> <out basename> <entry> [entry...]
set -eu
SRC=$1 OUT=$2; shift 2
HERE=$(dirname "$0")
case "$SRC" in
  *.c) gcc -O3 -mcpu=native -fPIC -fno-plt -ffreestanding -fno-builtin -fno-math-errno -ffp-contract=off \
           -fno-asynchronous-unwind-tables -fno-unwind-tables -fno-stack-protector -fno-tree-loop-distribute-patterns -c "$SRC" -o "$OUT.o" ;;
  *)   gcc -c "$SRC" -o "$OUT.o" ;;
esac
# Some compilers turn a plain copy into a call to memcpy and friends. If that is all that is missing, build again with those
# routines included in the piece itself (rt.h). Pieces that never needed them are built exactly as before.
case "$SRC" in *.c) if nm -u "$OUT.o" | grep -q . && ! nm -u "$OUT.o" | grep -qvE ' (memcpy|memset|memmove)$'; then
  gcc -O3 -mcpu=native -fPIC -fno-plt -ffreestanding -fno-builtin -fno-math-errno -ffp-contract=off -fno-asynchronous-unwind-tables -fno-unwind-tables -fno-stack-protector -fno-tree-loop-distribute-patterns -include "$HERE/rt.h" -c "$SRC" -o "$OUT.o"; fi ;; esac
# A piece must stand alone: any reference to something outside itself is refused here.
if nm -u "$OUT.o" | grep -q .; then echo "piece refers to outside symbols:" >&2; nm -u "$OUT.o" >&2; exit 1; fi
# One entry may not call another (or take the address of any exported thing): the compiler reaches those through an address
# table, and a flat piece carries none, so the call would jump to nothing. tls's reset did exactly that (2026-11-11).
# Share a static function between the entries instead.
if readelf -r "$OUT.o" | grep -q GOT; then echo "piece reaches one of its own entries through an address table (an entry calling an entry?); use a shared static function" >&2; exit 1; fi
ld -T "$HERE/flat.ld" --no-warn-rwx-segments -o "$OUT.elf" "$OUT.o"
# State belongs to the host: a piece with writable data of its own is refused.
if [ "$(size -A "$OUT.elf" | awk '$1==".data"||$1==".bss"{s+=$2} END{print s+0}')" != "0" ]; then echo "piece has writable data of its own; state belongs to the host" >&2; exit 1; fi
objcopy -O binary -j .text -j .rodata "$OUT.elf" "$OUT.bin"
# Machine code is read four bytes at a time; keep the blob a whole number of instructions long.
while [ $(( $(wc -c < "$OUT.bin") % 4 )) -ne 0 ]; do printf '\0' >> "$OUT.bin"; done
: > "$OUT.entries"
for E in "$@"; do printf '%s %d\n' "$E" "0x$(nm "$OUT.elf" | awk -v e="$E" '$3==e{print $1}')" >> "$OUT.entries"; done
rm -f "$OUT.o" "$OUT.elf"
