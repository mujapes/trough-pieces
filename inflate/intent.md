# Inflate

## What this is for
Unpacks compressed data. Web pages, scripts and style sheets nearly always arrive compressed with gzip; this
is the piece that turns those bytes back into the document, so Trough's own engine can read what the network
delivers. (The png piece carries the same method inside it for image data.)

## Entries
- **size**(block, numbers: handle of the packed bytes; how many; -) → for gzip data, the unpacked length the
  file states (its last four bytes); -1 if the handle is empty or the data is not gzip. The block is not used.
- **unpack**(block, numbers: handle of the packed bytes; how many; -) → unpacks into the block, starting at
  its payload (byte 64), and returns the number of bytes written; -1 if the handle is empty, the data is
  damaged, or the result does not fit. On -1 the block may be partly written.

## What it reads
- gzip (as web servers send it; the first member only), zlib, and raw deflate, told apart by their first bytes.
- All three kinds of deflate block: stored, fixed codes, dynamic codes.
- For gzip the stated length and the CRC-32 must match what was unpacked; for zlib the Adler-32 must. A
  mismatch is refused (-1). Raw deflate has no checksum.

## The blocks
- The packed bytes are a block of plain bytes (kind 2) at a handle.
- The block unpacked into is any host block whose header gives its size in bytes 16-23; the piece writes only
  between byte 64 and that size.

## Conventions
- Every read is checked against the packed data's size and every write against the room in the block.
- No state; calls nothing outside itself.
