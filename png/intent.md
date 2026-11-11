# PNG

## What this is for
Brings a picture in from a file. PNG is the web's lossless image format; this piece turns the bytes of a PNG
held at a handle into pixels on a surface. It is Trough's own decoder: its own inflate, its own filters.

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → as in paint.
- **size**(surface, numbers: png handle; how many; -) → width × 65536 + height of the image, or -1 if the
  handle is empty or the bytes are not a PNG this piece can read. The surface is not used.
- **decode**(surface, numbers: png handle, scratch handle; how many; -) → decodes the image onto the surface
  with its top-left corner at the surface's, replacing what was there (not blending); the part that does not
  fit is left out. Returns the number of pixels written, or -1 if the file is not a PNG this piece can read,
  is damaged, or the scratch block is missing or too small. On -1 the surface may be partly written.

## What it reads
- Every kind the format defines (version 3): greyscale at 1, 2, 4, 8 or 16 bits; RGB, greyscale with alpha
  and RGBA at 8 or 16 bits; palette images at 1, 2, 4 or 8 bits (with the palette's transparency if given).
  Interlaced files too (the seven-pass kind).
- A sample below 8 bits is scaled to 0-255 as value × 255 / the largest value for its depth. A 16-bit
  sample gives its high byte.
- A single transparent colour (tRNS in a greyscale or RGB file): pixels whose samples equal it exactly, at
  the file's own depth, get alpha 0.
- Checked against the standard PNG library: 184 files across every kind, depth and both layouts, sizes from
  1 × 1 up, every pixel identical on the reference and fast builds. On the single transparent colour in RGB
  the comparison tool (pngtopam) left those pixels opaque; the format's rule and Java's decoder agree with
  this piece.
- The compressed data may be split across any number of IDAT chunks. Every chunk's checksum (CRC-32) is
  verified before anything is decoded; a file with a damaged chunk is refused.

## The scratch block
Plain memory the host lends (kind 5), at least 64 + height × (1 + width × bytes per pixel) bytes (an interlaced file needs somewhat more, because its seven passes have nearly twice as many rows, each with its own leading byte: the exact amount is the sum over the passes of rows × (1 + row bytes)): the piece
inflates the filtered rows into it. Nothing is kept there between calls.

## Conventions
- Every read is checked against the file's size and every write against the scratch block and the surface.
- Pixels are written as red, green, blue, alpha (paint/intent.md); images without alpha get 255.
- No state; calls nothing outside itself.
