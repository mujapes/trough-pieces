# Fill

## What this is for
Fills any outline on a surface with smooth edges. Letters at any size, rounded corners, icons: all are outlines
to fill. This is the general painter; paint and text are its fast special cases.

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → as in paint.
- **fill_path**(surface, numbers, how many, colour) → fills the shape and returns how many pixels received any
  ink, or -1 if the numbers are not a well-formed shape (then nothing is painted).

## The shape
The numbers are one or more closed outlines, each written as a count of points followed by that many x y
pairs. Coordinates are in sixteenths of a pixel (16 means one pixel), x rightward, y downward. Each outline is
closed by joining its last point back to its first. A shape is well formed when every count is between 2 and
256, the numbers end exactly at the end of an outline, there is at least one outline, and there are at most
1024 points in all.

## What "inside" means (all whole-number arithmetic)
- Each pixel is tested at 16 places: sample columns at 2, 6, 10 and 14 sixteenths across it, on sample rows at
  2, 6, 10 and 14 sixteenths down it.
- An edge from (x0, y0) to (x1, y1) crosses sample row Y when y0 ≤ Y < y1 (counting +1) or y1 ≤ Y < y0
  (counting -1), at x = x0 + floor((Y - y0) × (x1 - x0) / (y1 - y0)).
- Along a sample row, crossings are taken in order of x (crossings at the same x in the order their edges
  appear in the numbers). A sample at column position X is inside when the running count of the crossings at
  positions ≤ X is not zero.
- A pixel with n of its 16 samples inside has ink i = (n × 255 + 8) / 16.

## Blending
As the text piece: a = (i × A + 127) / 255 for the colour's alpha A; each byte becomes
(S × a + D × (255 - a) + 127) / 255 with S the colour's red, green, blue, or 255 for alpha. Ink 0 leaves the
pixel untouched. Colour is 0xAABBGGRR.

## Conventions
- Pixels outside the surface are never written. No state; calls nothing outside itself; scratch space is on
  the stack and gone when the call returns.
