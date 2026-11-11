# Image

## What this is for
Puts one picture onto another: icons, photos, video frames, thumbnails of windows. The fourth drawing
primitive after rectangles, text and filled shapes.

## Entries (surfaces are as described in paint/intent.md; the first is the one drawn on)
- **check**(surface) → as in paint.
- **blit**(surface, numbers: handle, x, y; how many; -) → copies the whole picture held at that handle so its
  top-left corner lands at x, y. Returns how many pixels of the surface were touched, or -1 if the handle is
  empty or what it holds is not a sound picture.
- **scale**(surface, numbers: handle, x, y, w, h; how many; -) → draws the whole picture stretched or shrunk
  into the rectangle x, y, w, h. Returns pixels touched; 0 if w or h is not positive; -1 as for blit.
- **smooth**(surface, numbers: handle, x, y, w, h; how many; -) → as scale, but each pixel is a blend of the
  part of the picture it covers, so a shrunken picture keeps its fine detail as shading. Same answers as scale.
- **stretch**(surface, the same numbers) → as scale, but each pixel is a blend of the four source pixels
  around the point it comes from, so an enlarged picture is soft instead of blocky. Use smooth when making a
  picture smaller and stretch when making it larger. Same answers as scale.
Missing numbers count as 0. A picture may not be drawn onto itself (-1).

## Conventions
- The source is reached through the call table's handles (slots.txt); its header is checked exactly as the
  destination's is, every call.
- Scaling picks, for the pixel at column c and row r of the rectangle, the source pixel at column
  floor((2c + 1) × W / (2w)) and row floor((2r + 1) × H / (2h)), W and H being the source's size (nearest
  neighbour; smoother scaling comes later).
- Smooth scaling looks at 16 points of the source for the pixel at column c, row r: columns
  floor((8c + 2i + 1) × W / (8w)) for i = 0 to 3 and rows floor((8r + 2j + 1) × H / (8h)) for j = 0 to 3. With A
  the sum of their alphas: if A is 0 the pixel is left alone; otherwise its red, green and blue are each
  (sum of colour × alpha + A / 2) / A (whole-number division), so see-through pixels do not darken edges, and
  its alpha is (A + 8) / 16. That blended pixel is then laid over what is there like any other.
- Stretch (version 3): for column c of the rectangle, u = floor((2c + 1) × W × 256 / (2w)) − 128, held to
  0 .. (W − 1) × 256; the left source column is u / 256 (whole part), the right one is the next (or the same
  at the edge), and fx is u's remainder (0-255). Rows likewise give fy. The four pixels weigh
  (256 − fx)(256 − fy), fx(256 − fy), (256 − fx)fy and fx·fy. With A the sum of weight × alpha: if A is 0 the
  pixel is left alone; otherwise red, green and blue are each (sum of weight × alpha × colour + A / 2) / A
  and alpha is (A + 32768) / 65536 (whole-number division); an alpha of 0 leaves the pixel alone.
- Each source pixel is laid over what is there by its own alpha a: every byte becomes
  (S × a + D × (255 - a) + 127) / 255, with S the source's red, green or blue, or 255 for the alpha byte.
  Alpha 0 leaves the pixel untouched and does not count as touched.
- Pixels outside the destination are never written; the source is only read. No state; calls nothing.
