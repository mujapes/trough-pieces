# Charset

## What this is for
Text arrives as bytes, and which letters they mean depends on the encoding. Modern pages use UTF-8; many
older ones use the Windows Western encoding or UTF-16. This piece turns those into UTF-8, which is what the
rest of Trough reads, and repairs damaged text the way browsers do instead of refusing it.

## Entries
- **to_utf8**(block, numbers: source handle, encoding) → writes the text as UTF-8 into the block from byte 64
  and returns its length. encoding: 1 UTF-8, 2 windows-1252, 3 UTF-16 little-endian, 4 UTF-16 big-endian.
  A byte-order mark at the start, in the matching encoding, is dropped. -1 for an empty handle, bytes that
  are not plain (kind 2), another encoding number, or a result that does not fit.
- **named**(-, numbers: label handle) → which encoding a label means (from a Content-Type header or a page's
  own declaration), as browsers read labels: spaces, quotes and a trailing semicolon around it are ignored
  and case does not matter. "iso-8859-1", "latin1" and "ascii" mean windows-1252, because that is what such
  pages contain. "utf-16" means little-endian. 0 for a label it does not know; -1 for an empty handle.

## Conventions
- UTF-8 in: each stretch that cannot be part of a well-formed character becomes one U+FFFD, taking the
  longest start of a character that could still have been completed (overlong forms, surrogates and values
  past U+10FFFF are not well formed).
- windows-1252: the five bytes its table leaves undefined become the same-numbered control characters.
- UTF-16: a surrogate without its partner becomes U+FFFD and the unit after it is read afresh; text that
  ends inside a pair, or with one odd byte, ends with one U+FFFD.
- No state; calls nothing.

## Measured and checked
Agrees with Python's own converters on 1,201 conversions: every byte value of windows-1252, 600 UTF-8
strings (400 of them deliberately damaged, 200 random bytes), 400 UTF-16 strings in both byte orders with
broken pairs and odd lengths, and 11 labels (`charset/checks/check.py`). The first run found one fault: a
cut-off pair followed by a stray byte gave two marks, not one.
