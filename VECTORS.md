# Recorded checks ("vectors")

A piece's checks are recorded once, by running its reference build, and replayed against any implementation,
anywhere: on the bench, and inside the app before a piece is allowed to run. Nothing about a particular piece
is written in Trough's Java code. Because pieces are bit-exact, a recording made from the reference is valid
for every correct implementation.

## Manifest: out/<piece>.piece (text)
    state <bytes>            0 for a piece without memory, otherwise the size of its state block (512)
    entry <name> <argmin> <argmax>     one line per entry, in order; with state, entry 0 is migrate (or check)
    surface <w> <h>          the state block is a picture; this is the size used for the recorded checks
    style text               recorded inputs are x, y, then character codes (flag 16)
    style image              recorded inputs are a handle, then x y w h (flag 64)
    style font               recorded inputs are a handle, size, x, y, then character codes (flag 128)
    fixture <file>           a file beside the manifest, held at handle 0 while the checks run (flag 128)
    style path               recorded inputs are mostly one outline: a point count, then x y pairs (flag 32)
    needs <socket>           a call-table socket this piece calls through (slots.txt)

## Vectors: out/<piece>.vectors (binary, little-endian)
Header: the 8 bytes "TRPIECE1", then u32 record count.
Each record:
    u8  entry index
    u8  flags: 1 = samples are passed, 2 = start from an all-zero state block first,
               4 = start from the explicit state block that follows this header,
               8 = start from a fresh surface of the manifest's size (paint/intent.md),
               16 = after generating, every number from the third on becomes a character code:
                    20 + ((number + 32768) mod 115),
               32 = after generating, the first number becomes (count - 1) / 2: the point count of one
                    outline made of the remaining numbers,
               64 = handle 0 holds the standard test picture (24 by 16; at column x, row y: red
                    (37x + 11y) mod 256, green (5x + 53y) mod 256, blue (7xy + 3) mod 256, alpha 0 when
                    x + y is a multiple of 5, else 128 when x mod 7 is 3, else 255), handle 1 is empty, and
                    the first number becomes 1 if it was a multiple of 5, otherwise 0,
               128 = the manifest's fixture file is at handle 0 as a block of bytes (kind 2), handle 1 is
                    empty, the first number becomes 1 if it was a multiple of 5, otherwise 0, and every
                    number from the fifth on becomes a character code as for flag 16
    u16 reserved (0)
    u32 count                 number of 16-bit samples
    u32 seed, u32 span        samples are generated, not stored (see below)
    i64 argument
    i64 expected result
    [flags&4] state block bytes (as many as the manifest says)
    [state>0] 20 bytes: SHA-1 of the state block after the call

Samples: seed' = seed * 1103515245 + 12345 (32-bit, wrapping) before each sample;
sample = ((seed' >> 8) mod (2*span+1)) - span, as a signed 16-bit value.
Calling shapes: without state, entry(samples, count, argument); with state, entry(state, samples, count,
argument), samples absent (null, count 0) when flag 1 is clear. State carries from one record to the next
unless flag 2 or 4 resets it.

## Format 2 and 3: described setups (magic TRPIECE2 / TRPIECE3)

The manifest describes the setup and the inputs, instead of one flag bit per kind of case.

    target surface <w> <h> | target mask <w> <h> | target state <bytes>
                             the block passed as the first argument. Fresh means: a picture or mask with its
                             header and zero pixels; for state, all zero (entry 0, migrate, is called next).
    hold <handle> file <name>            a file beside the manifest, as bytes (kind 2)
    hold <handle> surface <w> <h>        an empty picture        hold <handle> mask <w> <h>    an empty mask
    hold <handle> block <kind> <bytes>   zeroed memory of that kind (3 = the font's letter cache)
    hold <handle> picture                the standard test picture
    numbers <entry> <lowest count> <highest count> <field> ...   how that entry's numbers are made; the last
                             field repeats. Fields: pick:a,b,c (at most eight choices)  range:lo:hi  fixed:v  chars  raw:span
    fingerprint all                      write format 3 (below)

Numbers come from one stream: seed' = seed × 1103515245 + 12345 (32-bit), each use taking seed' >> 8. First the
count (lowest + value mod (highest - lowest + 1)), then one value per number: pick → list[value mod length];
range → lo + value mod (hi - lo + 1); fixed → v; chars → 20 + value mod 115; raw → value mod (2 span + 1) - span.

Header: 8 bytes of magic, u32 record count. Each record: u8 entry, u8 flags (8 = fresh target first, 16 =
everything held is made new first), u16 zero, u32 seed, i64 argument, i64 expected answer, 20-byte fingerprint.
The recorder writes 40 runs: a fresh start calling entry 0, then 150 calls that build on each other.

Fingerprint, format 2: SHA-1 of the target. Format 3: SHA-1 of the target's SHA-1 followed by the SHA-1 of each
held picture, mask or block (not files, not the test picture) in manifest order, so what a piece writes through
a handle is checked too.
