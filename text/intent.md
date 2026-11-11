# Text

## What this is for
Letters on a surface. This first version has one face at one size (the phone's own sans-serif at 18 pixels),
with the letter shapes carried inside the piece as constants made by tools/font_table.py from the font's
outlines. Text at any size needs a piece that fills outlines itself; that comes later.

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → as in paint: 1 if the header is one this piece can draw on, else 0.
- **draw**(surface, numbers, how many, colour) → the numbers are x, y, then character codes. Draws the
  characters left to right with the top of the line at y, starting at x. Returns the x where the next character
  would start. Codes outside 32 to 126 draw nothing and take no room.
- **measure**(surface, numbers, how many, -) → the numbers are character codes only. Returns the width the
  characters would take: the sum of their advances. Draws nothing; the surface is not read.

## Conventions
- Each letter is a grid of ink amounts, 0 to 255. Where the ink is i and the colour's alpha is A, the amount
  a = (i × A + 127) / 255 (whole-number division). Then each of the four bytes of the pixel becomes
  (S × a + D × (255 - a) + 127) / 255, where D is the byte already there and S is the colour's red, green or
  blue, or 255 for the alpha byte. Ink of 0 leaves the pixel untouched.
- Pixels outside the surface are skipped one by one; nothing outside the pixels is ever written.
- The line is 22 pixels tall with the baseline 17 below its top. Colour is 0xAABBGGRR as in paint.
- No state of its own; calls nothing outside itself.
