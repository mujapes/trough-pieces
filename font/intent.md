# Font

## What this is for
Text at any size from a real font file, read while the app runs. The file is plain bytes in a block the host
owns, reached through a handle; this piece finds each character's outline, scales it, turns its curves into
short lines and has the fill piece paint it. First part of Trough's own browser engine.

## Blocks of bytes
A block of plain bytes has the same 64-byte header as a picture, with kind 2 in bytes 0-3 (a picture is kind 1)
and the whole block's size in bytes 16-23; the bytes start at 64.

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → as in paint.
- **draw**(surface, numbers: font handle, size, x, baseline y, then character codes; how many; colour) → draws
  the characters left to right starting at pixel x with their baseline at pixel y, size pixels to the em.
  Returns where the next character would start, in sixteenths of a pixel; or -1 if the handle is empty, the
  block is not a TrueType font this piece can read, or the size is not between 4 and 1000.
- **measure**(surface, numbers: font handle, size, then character codes; how many; -) → the width the
  characters would take, in sixteenths of a pixel; -1 as for draw. The surface is not used.

- **draw_cached**(surface, numbers: font handle, cache handle, scratch handle, size, x, baseline y, then
  character codes; how many; colour) → as draw, but each letter's ink is worked out once per size, kept in the
  cache, and blended from there afterwards. Each letter is placed on a whole pixel: at floor((pen + 8) / 16)
  where pen is in sixteenths. Returns the pen position in sixteenths like draw, or -1 as draw does, and also
  if the cache handle is not a cache block (kind 3, at least 20 kB) or the scratch handle is not a mask of at
  least 16 by 16.

## The letter cache
- The cache block is plain memory the host owns (kind 3); a cache that is all zeros is empty and is set up on
  first use: 1024 slots, then the ink. A letter and size hash to a slot (up to 8 tried). On a miss with a free
  slot and room for the ink, the letter is covered into the scratch mask (cover cover_path, socket 10) at the
  origin and its ink copied into the cache.
- If there is no free slot or no room, or the letter is larger than the scratch mask, that letter is drawn
  through fill at the same whole-pixel position instead. What is on the surface never depends on what the
  cache already held, only how fast it got there.
- Blending from the cache uses the same arithmetic as the text piece.

## Conventions
- Every read of the font is checked against the block's size; a file that points outside itself is refused.
- Characters the font has no outline for take their advance and draw nothing. Composite characters are drawn
  from their parts without scaling the parts. Characters beyond the font's first character map are skipped.
- A font-unit value v becomes floor((v × size × 16 + unitsPerEm / 2) / unitsPerEm) sixteenths of a pixel; x is
  added to the pen position, y is subtracted from the baseline.
- Between two off-curve points the implied point is floor of their average. A curve from P0 through control
  P1 to P2 is replaced by four lines through the points floor(((4-k)² P0 + 2k(4-k) P1 + k² P2 + 8) / 16) for
  k = 1 to 4. Outlines with fewer than 2 or more than 256 points, or a point outside ±32767 sixteenths, are
  left out.
- Kerning (version 3): before each character after the first, the pen moves by the font's own adjustment for
  that pair of neighbours, scaled like any font-unit value (so it may be negative). The adjustment is read
  from the font's GPOS table: the lookups of every feature tagged "kern", in the font's order; in each, the
  first pair-adjustment subtable (format 1 or 2, directly or through an extension) that covers the left glyph
  and has the pair gives its first value's x-advance. Script and language are not consulted. Characters
  skipped because their code is negative do not separate a pair. A font without the table, or with a damaged
  one, simply has no kerning. measure includes it, so widths and drawing agree.
- Checked against an independent font library (fontTools): 3,000 random strings at 8 sizes, 3,134 kerned
  pairs among them, every width identical.
- Uses, through the call table: fill fill_path (socket 7), which does the painting and the clipping.
- No state; nothing is written except through fill.
