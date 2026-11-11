# Cover

## What this is for
Works out how much ink a shape puts on each pixel, without painting any colour. The result is kept (by the font
piece's letter cache, for one) and blended later, any number of times, in any colour.

## The mask
A block shaped like a surface (paint/intent.md) but with one byte per pixel: version 4 in bytes 0-3, bytes per
row equal to the width, size 64 + width × height.

## Entries
- **check**(mask) → 1 if the header is a sound mask, else 0.
- **cover_path**(mask, numbers, how many, -) → the shape is exactly the fill piece's (fill/intent.md): outlines
  as a count and x y pairs in sixteenths of a pixel, the same 16 samples, the same rule for inside. Every pixel
  with any sample inside is SET to its ink i = (n × 255 + 8) / 16; other pixels are left as they were. Returns
  how many pixels were set, or -1 for a malformed shape (nothing written).

## Conventions
- Pixels outside the mask are never written. No state; calls nothing outside itself.
