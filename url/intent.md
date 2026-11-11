# URL

## What this is for
Web addresses. A browser needs to take one apart (which site, which port, what to ask for) and to work out
where a link on a page really points, given the address of the page it is on. Without this no link can be
followed. This is the generic syntax and the reference resolution of RFC 3986.

## Entries
- **resolve**(block, numbers: base handle, reference handle) → the absolute address the reference points to
  when found on the page at base, written into the block from byte 64; returns its length. The base must have
  a scheme. The scheme and the site come out in small letters (anything before an "@" is left alone).
- **part**(block, numbers: address handle, which) → copies one part out and returns its length: 0 the scheme,
  1 the site (without "user@" or ":port"; an address in square brackets keeps them), 2 the path, 3 the query,
  4 the fragment, 5 what to ask the server for: the path ("/" if empty) and then "?" and the query if there
  is one. -1 if that part is absent (an empty query is present; no "?" at all is absent).
- **port**(-, numbers: address handle) → the port to connect to: the one written, else 443 for https and 80
  for http; -1 if there is no site, the port is not a number up to 65535, or the scheme has no usual port.
All return -1 for an empty handle, bytes that are not plain (kind 2), an address over 2,000 bytes, or a
result that does not fit the block.

## Conventions
- An address is split as scheme ":" ["//" authority] path ["?" query] ["#" fragment], exactly as appendix B
  of the RFC does; nothing is unescaped or re-escaped.
- resolve follows section 5.2 step by step, including the removal of "." and ".." steps (5.2.4): ".." above
  the top stays at the top. A "?" or "#" with nothing after it is kept. Doubled slashes inside a path are kept.
- No state; calls nothing.

## Measured and checked
- All 42 worked examples in section 5.4 of the RFC, normal and abnormal.
- 3,000 random links against Python's urllib: 2,380 identical; every other difference comes from two things
  that library does and the RFC does not (dropping an empty "?" or "#", squeezing "//" in a path), which this
  piece does not copy (`url/checks/check.py`).

## Implementations
- `reference.c`: the meaning, compiled (7,812 bytes).
- `impl.S` (live): written by hand in ARM64 (2,508 bytes, 32%). Passed the 6,040 recorded checks and the 42 examples of RFC 3986 section 5.4 on its first complete run; same answers as the compiled build on the 3,000 random links. Speed not measured (a single address takes well under a microsecond either way).
