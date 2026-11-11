# Home

## What this is for
The home screen, as a piece. It decides what the screen looks like and where things are, and paints by asking
the paint and text pieces through the call table. It holds no pixels and no drawing code of its own, so the
look of the home screen can be replaced in about a second while Trough runs.

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → 1 if the header is sound (as in paint), else 0.
- **render**(surface, numbers, how many, -) → paints the whole home screen. Numbers: the tile being pressed
  (0 to 15, anything else for none), the hour, the minute. Missing numbers count as none, 0 and 0. Hours and
  minutes outside the clock wrap round. Returns how many painting calls it made.
- **hit**(surface, numbers x y, how many, -) → which tile is at that point: 0 to 15, or -1 for none. The
  surface is only read for its size. Missing numbers count as 0.

## Layout (worked out from the surface's width W and height H, whole-number arithmetic)
- A status strip 28 pixels tall across the top, with the time at its left.
- A title line centred under it at y = 34.
- Sixteen tiles in four columns and four rows, reading left to right, top to bottom. Column width is W / 4.
  A tile is a square two thirds of a column wide, centred in its column. Rows start at y = 64 and are
  (H - 64 - H / 7 - 12) / 4 apart. Its name is centred under it, 4 pixels below the tile.
- A dock H / 9 tall, 12 pixels from the bottom, inset 16 pixels at each side, holding four small squares.
- A pressed tile gets a light frame 3 pixels wide.
- hit answers a tile for any point inside that tile's square.

## Uses
Through the call table: paint clear (socket 3), paint fill_rect (4), text draw (5), text measure (6).

## Conventions
- No state of its own. Never writes to the surface itself: every pixel goes through paint or text, which clip.
