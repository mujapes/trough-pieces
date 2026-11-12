# Page

## What this is for
Reads a web page (HTML held as bytes at a handle) and lays it out on a surface: the first slice of Trough's own
browser engine. It decides where every word goes and has the font piece draw it.

## Entries (the surface is the one described in paint/intent.md)
- **check**(surface) → as in paint.
- **render**(surface, numbers: page handle, font handle, text size, scroll, then optionally a cache handle
  and a scratch-mask handle; how many; -) → paints the page on a white background, scrolled up by that many
  pixels. With a cache block and a scratch mask at those handles, lines are drawn through the font piece's
  letter cache (font draw_cached, socket 11), which is much faster; otherwise through font draw. The layout
  is the same either way. Returns the height of the whole laid-out page in
  pixels, or -1 if either handle is empty or not a block of bytes, or the size is not between 6 and 200.

## What it understands so far
- Text, with runs of spaces, tabs and line ends treated as one space; UTF-8; the character references
  &amp; &lt; &gt; &quot; &apos; &nbsp; and &#number;.
- Blocks, each starting on a new line: p, div, section, article, header, footer, main, ul, ol, blockquote, tr,
  h1 to h6 (2, 1.5, 1.17, 1, 0.83 and 0.67 times the text size), li (begins with a bullet), and br (a line
  break). Space above and below a block: h1 0.67, h2 0.83, h3 1, other headings and p 1, li 0, others 0 times
  its own text size; where two spaces meet, the larger one is used.
- Links (a): drawn in blue. Everything else inline is drawn as plain text.
- Skipped entirely: comments, and the contents of head, script, style, title, noscript, svg.
- Not yet: images, tables, bold and italic, colours and styles, forms, anything positioned.

## Layout
- A margin of 8 pixels all round. Lines are 1.25 times the text size apart (whole pixels), with the baseline
  one text size below the top of the line. Words are separated by the width of a space; a word that does not
  fit on the line starts the next one; a single word wider than the line is drawn anyway.
- Widths come from the font piece's measure, in sixteenths of a pixel.

## Uses
Through the call table: paint clear (socket 3), font draw (8), font measure (9), font draw_cached (11).

## Conventions
- Every read of the page is checked against the block's size. No state; nothing is written except through
  the pieces it calls.

## link (added 2026-11-12)
- **link**(block, numbers: page handle, font handle, text size, scroll, x, y, screen width, screen height) → which
  address the text at the point leads to: written into the block from byte 64, its length returned; 0 if the point is
  not on link text; -1 if the numbers are not usable (fewer than 8, a bad handle, size outside 6 to 200, width or
  height below 16) or the address does not fit. The page is laid out exactly as `render` lays it out, measuring
  where it would draw, so the answer always agrees with the picture. The address is what the opening tag gives after
  `href` (any case; in double quotes, single quotes or bare), as written: making it absolute is the url piece's job.
  Checked against the picture: every link-coloured dot of a drawn test page answers with its own address and every
  plain-text dot with none (three links, three ways of writing the address, wrapped lines, scrolled).

## Pictures (added 2026-11-12)
An `<img>` that states a width and a height (8 to 4096 each) gets a line of its own with that much room, shrunk in
proportion if wider than the page less its margins, and a quarter of a line below it. The piece draws nothing
there. Pictures with no stated size, or smaller than 8 either way, take no room and are not listed.
- **pictures**(block, numbers: page handle, font handle, text size, screen width) → writes one record for each such
  picture into the block from byte 64 and returns how many bytes were written (-1 if the numbers are not usable; a
  record that does not fit is left out). A record: five 32-bit numbers (left, top counted from the top of the page,
  width, height, the address's length), then the address as written after `src`, filled out with zeros to a
  multiple of four bytes. Fetching, decoding and drawing the picture into that room is the host's and the image
  piece's work.
