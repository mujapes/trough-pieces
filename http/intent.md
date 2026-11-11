# HTTP

## What this is for
Reads what a web server sends back: the status line, the headers, and the body. With inflate (to unpack) and
page (to lay out), this completes the path from the bytes off the network to a drawn page. The network
connection itself is the host's; this piece only reads the reply.

## Entries (the reply is a block of plain bytes, kind 2, at a handle)
- **status**(block, numbers: reply handle; how many; -) → the status code (200, 404, ...), or -1 if the handle
  is empty or the bytes do not begin with a well-formed HTTP/1.x status line. The block is not used.
- **header**(block, numbers: reply handle, then the header's name as character codes; how many; -) → copies
  that header's value (without surrounding spaces) into the block from byte 64 and returns its length; -1 if
  there is no such header, or it does not fit. Names match without regard to case; the first match wins.
- **body**(block, numbers: reply handle; how many; -) → copies the body into the block from byte 64 and returns
  its length. If the reply says Transfer-Encoding: chunked, the chunks are joined. Otherwise, if it gives a
  Content-Length, that many bytes are taken (-1 if fewer are present); otherwise everything after the headers.
  -1 if the reply is malformed or the body does not fit. The body is copied as sent: if Content-Encoding says
  gzip it is still packed, and inflate unpacks it.
- **packed**(block, numbers: reply handle; how many; -) → 1 if Content-Encoding is gzip, 0 if not, -1 if the
  reply is malformed. The block is not used.

- **request**(block, numbers: address handle; how many; -) → writes what a browser sends to ask for the page at
  that address (an absolute http or https address, best passed through url resolve first), and returns its
  length: a GET for the path and query, the Host (with the port only when it is not the usual one for the
  scheme), a User-Agent of Trough/0.1, that it accepts gzip, and that the connection closes afterwards.
  -1 if the address has no site or no usable port, contains a space or control character, or does not fit.
  Uses url part and port through the call table (sockets 32, 33).

## Conventions
- The headers end at the first empty line (CR LF CR LF, or LF LF). A header line is "name: value".
- The block written to is any host block whose header gives its size in bytes 16-23; only bytes 64 to that
  size are written. Every read is checked against the reply's size.
- No state; calls nothing outside itself.

## Implementations
- `reference.c`: the meaning, compiled (5,608 bytes).
- `impl.S` (live): written by hand in ARM64 (2,492 bytes, 44%). Passed the 6,040 recorded checks on its first run. Its request entry calls the hand-written url piece through a table of its own that carries the real sockets.
