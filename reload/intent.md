# reload

## What this is for
Hot reload is what Trough is built on (RELOAD.md). New machine code arrives as records in one growing stream; this
piece is the judge of a record: whole or still arriving, well formed or not, and whether its seal matches its
bytes. Nothing from the stream may be run unless this piece has answered with the record's length.

## A record
All numbers little-endian. `TRPC`; u32 total length of the record; u32 name length; u32 entries length; u32 code
length; 12 zero bytes; then the name, the entries list (text: one `name offset` to a line) and the code, one after
another; then 32 bytes: the SHA-256 of everything in the record before them. So total = 32 + name + entries +
code + 32. A name is 1 to 40 of `a`-`z`, `0`-`9`, `-`; entries are 1 to 4096 bytes; code is 4 to 1048576 bytes
and a multiple of 4 (ARM64 instructions).

## Entries
- **record**(block, numbers: stream handle; how many; argument: where in the stream the record starts) → the
  record's total length if a whole, well-formed record with a matching seal starts there. 0 if the stream ends
  before the record does (it is still being written: look again later). -1 if what is there cannot be a record
  (wrong first four bytes, lengths that do not add up or are out of range, a name with other characters, nonzero
  padding) or the seal does not match. -2 if the block (used as working room, at least the record's length) is too
  small or is the stream itself. The block's contents are working room and mean nothing afterwards.
- **part**(block, numbers: stream handle, which; how many; argument: where the record starts) → copies one part
  into the block from byte 64 and returns its length: 0 the name, 1 the entries list, 2 the code. -1 unless
  `record` would answer with a length for the same place (it is asked first, every time), or `which` is not 0 to
  2, or the part does not fit.

## Conventions
- No state. Calls the hash piece (socket 14, SHA-256) with a table of its own.
- The answer to `record` is the only gate: `part` never hands out bytes of a record that fails it.

## take and back [by Opus, 2026-11-13]
- **take**(ledger, sockets, how many 1-64, argument: where the new addresses are, table): swaps a group of sockets to new
  code in one step. Everything is checked first (socket over 255, a socket twice, an empty address: -1, nothing changed).
  Each socket's old address and a count go to the ledger (16 bytes a socket, 4096 bytes); the new address is stored with
  release order. Answer: the first socket's count. Old code is not unmapped; callers inside it finish there.
- **back**(ledger, sockets, how many): puts the kept addresses back and clears them; -1 if any has none kept.
Checked by `checks/swap.c` (10 checks).
