# Paint

## What this is for
The first pieces that draw. A surface is a picture the host owns: pieces write colours into it and Trough shows
it on screen. Everything visible is eventually made of these operations.

## The surface (owned by the host, little-endian)
| bytes | what |
| 0-3 | layout version (1) |
| 4-7 | width in pixels |
| 8-11 | height in pixels |
| 12-15 | bytes per row (4 × width) |
| 16-23 | size of the whole block in bytes (64 + rows) |
| 24-63 | zero, reserved |
| 64- | pixels, row by row from the top, 4 bytes each; the colour number is stored as given |

## Entries
- **check**(surface) → 1 if the header describes a surface this piece can paint (version 1, width and height
  between 1 and 16384, bytes per row equal to 4 × width, size equal to 64 + bytes per row × height), else 0.
  The host calls it before anything else and after any swap; the other entries may assume it returned 1.
- **clear**(surface, -, -, colour) → paints every pixel; returns how many.
- **fill_rect**(surface, numbers x y w h, how many, colour) → paints the part of the rectangle that lies on the
  surface and nothing else; returns how many pixels were painted. Numbers not supplied count as 0. A rectangle
  wholly off the surface, or with no width or height, paints nothing and returns 0.

## Conventions
- A piece never writes outside the pixels of the surface it was handed, whatever the numbers.
- A colour is the number 0xAABBGGRR: in memory the four bytes of a pixel are red, green, blue, then alpha
  (255 is solid). This is the order Android bitmaps use, so a surface can be shown without converting it.
- Only the low 32 bits of the colour are used. No state of its own; calls nothing outside itself.
