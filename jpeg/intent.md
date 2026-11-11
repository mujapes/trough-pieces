# JPEG

## What this is for
Brings a photograph in from a file. JPEG is the format of nearly every photo on the web, and its method (small
squares, each stored as strengths of patterns, with fine detail thrown away) is the basis of video too. This
piece turns the bytes of a JPEG held at a handle into pixels on a surface. It is Trough's own decoder.

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → as in paint.
- **size**(surface, numbers: jpeg handle; how many; -) → width × 65536 + height of the image, or -1 if the
  handle is empty or the bytes are not a JPEG this piece can read. The surface is not used.
- **decode**(surface, numbers: jpeg handle, scratch handle; how many; -) → decodes the image onto the surface
  with its top-left corner at the surface's, replacing what was there; the part that does not fit is left
  out. Returns the number of pixels written, or -1 if the file is not one this piece can read, a code in it
  cannot be decoded, or the scratch block is missing or too small.

## What it reads
- Baseline (sequential) JPEG, 8 bits a sample, Huffman coded: greyscale, or three components (brightness and
  two colour planes) with the brightness at 1×1, 2×1 or 2×2 samples per colour sample.
- Progressive JPEG as well (version 2): the same picture sent as several scans, coarse first. Any scan order
  the format allows, including successive refinement and restart intervals. The coefficients are kept until
  the last scan and the picture is produced once; a file that stops early gives the picture as far as it got.
- Restart intervals. Lossless, extended (12-bit) and arithmetic-coded files are refused.

## How it decodes (whole-number arithmetic throughout, so every correct implementation gives the same pixels)
- Each 8 × 8 square: the coefficients are multiplied by the file's quantisation table and put through the
  inverse transform in the "slow integer" form (13-bit constants; the column pass keeps 2 extra bits, the row
  pass removes 17 and adds 128), then held to 0-255.
- Colour planes stored at half size are enlarged by repeating each sample (no smoothing).
- With Y the brightness and Cb, Cr the colour samples less 128: red = (65536 Y + 91881 Cr + 32768) >> 16,
  green = (65536 Y - 22554 Cb - 46802 Cr + 32768) >> 16, blue = (65536 Y + 116130 Cb + 32768) >> 16, each held
  to 0-255. Alpha is 255.
- A progressive file decodes to exactly the pixels of the same picture stored the ordinary way (40 pictures
  made both ways with the standard tools: every pixel identical, on the reference and the fast build).
- Measured against the standard reference decoder (integer transform, no smoothing) on five photographs:
  no pixel differed by more than 2 levels, and the mean difference was under 0.01.

## The scratch block
Plain memory the host lends (kind 5), big enough for every component's samples rounded up to whole blocks.
A progressive file needs three times that (two more bytes for every sample, for the coefficients).
Nothing is kept there between calls.

## Conventions
- Every read is checked against the file's size. A damaged file may decode to nonsense, but nothing is ever
  read or written outside the file, the scratch block and the surface.
- No state; calls nothing outside itself.
