# GIF

## What this is for
The third web picture format, and the one that moves: a GIF holds one or more frames, each a patch of up to
256 colours laid onto a shared canvas, with a time to stay up. This piece reads a GIF held at a handle and
draws any frame as it should appear. It is Trough's own decoder (own LZW).

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → as in paint.
- **size**(surface, numbers: gif handle; how many; -) → width × 65536 + height of the canvas, or -1 if the
  handle is empty or the bytes are not a GIF. The surface is not used.
- **frames**(surface, numbers: gif handle; how many; -) → how many frames the file holds (as far as it can be
  followed), or -1 as for size. The surface is not used.
- **delay**(surface, numbers: gif handle, frame; how many; -) → how long that frame stays up, in hundredths of
  a second as the file gives it (0 if it does not say), or -1 as for size or if there is no such frame.
- **decode**(surface, numbers: gif handle, scratch handle, frame; how many; -) → draws the canvas as it
  stands when that frame (counting from 0) is showing, with its top-left corner at the surface's; the part
  that does not fit is left out. Returns the number of pixels of the surface covered by the canvas, or -1 if
  the file cannot be read, there is no such frame, the data of that frame or one before it is damaged, or
  the scratch block is missing or too small.

## How a frame comes to look as it does
- The canvas starts clear (every byte 0: see-through). Frames are laid on in order, from frame 0 up to the
  one asked for, so later frames cost more; nothing is kept between calls.
- A frame's pixels are numbers into its colour table (its own if it has one, otherwise the file's). The
  frame's see-through number, if it names one, leaves the canvas as it was; any other writes red, green,
  blue and alpha 255. A number past the end of the table makes the file damaged.
- Before the next frame is laid on, the one before is disposed of as it asks: left in place (0 or 1), its
  patch cleared to see-through (2), or its patch put back to what was there before it (3).
- Interlaced frames (rows stored in four passes) are put back in order.
- A frame patch reaching outside the canvas is cut to it.

## The scratch block
Plain memory the host lends (kind 5): at least 64 + 20,480 + 5 × canvas width × canvas height bytes.

## Conventions
- Every read is checked against the file's size and every write against the scratch block and the surface.
- The repeat count and other extensions are skipped. No state; calls nothing.
