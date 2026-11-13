# Pieces

Trough built as small parts that are loaded as machine code while the app runs, checked before they are
trusted, and replaced without a rebuild. Started 2026-11-11 from one measurement: hand-written ARM64 for a
small audio routine ran 4.6 times faster than gcc's. The direction agreed with the user that night: the source
of a program is its description and its tests; the implementation is whatever is best today and is expected
to be regenerated as models improve.

## What a piece is

Three things kept together, in `<piece>/`:

1. `intent.md`: what it is for and the conventions that make that precise (exact arithmetic where it matters).
2. Recorded checks: thousands of cases recorded by running the reference build. A piece that fails them is
   never loaded. Formats in `VECTORS.md`.
3. An implementation: `reference.c` (the meaning, written the obvious way; often also the implementation), and
   sometimes a faster one (`impl.S` written by hand, `fast.c`). Built to a flat, position-independent blob.

A piece keeps nothing between calls, has no writable data of its own, and refers to nothing outside itself.
`build.sh` refuses anything else.

## How a piece is called

Every entry gets the call table as its last argument.

    without a block:  entry(numbers, count, argument, table)
    with a block:     entry(block, numbers, count, argument, table)

- **numbers** are 16-bit values: samples, coordinates, character codes, handles.
- **block** is memory the host owns: a piece's state, a picture, a mask. 64-byte header, then the payload. A piece may also hand a callee a block of its own, by passing a table of its own with that block at a handle (tls does this to reach hash, seal and exchange). That table must carry the real sockets 0-255 whenever the callee may call onward (trust copies them; a bare table made rsa's call to hash jump into stack rubbish, found 2026-11-11 by the recorder crashing).
  Bytes 0-3 say what it is: 1 picture (4 bytes a pixel), 2 plain bytes (a file), 3 the font's letter cache,
  4 mask (1 byte a pixel). State blocks carry a layout version instead and a `migrate` entry upgrades them.
- **table** (`slots.txt`, `slots.h`): sockets 0-255 hold the current address of other pieces' entries, so
  pieces call each other without knowing addresses and a swap repoints them. Sockets 256-511 are handles:
  the addresses of blocks the host is holding (handles 0-15 are reserved for checks).

## The pieces (all 20 loaded in the app as of 2026-11-11 11:37, screen off, by the keeper)

| piece | does | calls |
| sound-measures | energy and threshold climbs of microphone samples (hand-written) | |
| peak | largest sample (hand-written) | |
| listen-step | the listener's background level, loud/rhythm/clipping decision; state with migration | sound-measures, peak |
| voice-policy | the hands-free voice's tunable rules (skip ahead, ducking, waits) | |
| paint | clear and clipped rectangle fill on a picture (hand-written) | |
| text | one face at 18 px from a baked table (first text; superseded by font) | |
| fill | any outline, anti-aliased, non-zero winding, integer arithmetic | |
| cover | the same shapes as ink amounts into a mask | |
| image | copy, scale, smooth-shrink and smooth-enlarge one picture onto another | a picture at a handle |
| font | reads a TrueType file at a handle; text at any size; letter cache | fill, cover |
| page | reads HTML at a handle, lays out blocks and wrapped lines | paint, font |
| png | decodes a PNG file at a handle onto a picture: own inflate, own filters | a scratch block at a handle |
| http | reads a server's reply (status, a header by name, the body, joining chunks) and writes the request for an address | url |
| inflate | unpacks gzip, zlib and raw deflate data from a handle into a block: how web content arrives | |
| jpeg | decodes a baseline or progressive JPEG at a handle onto a picture: own Huffman, inverse transform, colour conversion | a scratch block at a handle |
| flac | decodes lossless music (FLAC, 16-bit, mono or stereo) at a handle into samples; both frame checksums verified | a scratch block at a handle |
| sound | changes a run of samples' rate, channels and volume (`convert` straight-line, `resample` filtered); mixes runs with clipping | samples at a handle |
| gif | decodes a GIF at a handle, still or animated: own LZW, frame disposal, transparency, interlace, delays | a scratch block at a handle |
| hash | SHA-256, SHA-384, SHA-512, HMAC-SHA-256 and TLS 1.3 key derivation (HKDF-Expand-Label) of bytes at a handle (processor's SHA instructions): first piece of the secure-connection stack | |
| seal | ChaCha20-Poly1305: locks and unlocks a record with a tag that catches any change | |
| exchange | X25519: a public value from a secret, and the shared secret from ours and theirs | |
| tls | TLS 1.3 client: hello, key schedule, records, the server's proof, and who the server is (through trust); state | hash, seal, exchange, trust |
| rsa | checks RSA signatures (PKCS #1 v1.5 with SHA-256/384/512; PSS with SHA-256): first part of certificate checking | hash |
| ecdsa | checks elliptic-curve signatures on P-256 and P-384: second part of certificate checking | |
| cert | reads an X.509 certificate at a handle: signed part, signature, key, dates, may-sign flag, names covered | |
| trust | certificate chain to a trusted root (signatures, dates, permissions, name) and the server's handshake signature | cert, hash, rsa, ecdsa |
| url | web addresses: where a link points (RFC 3986 resolution), parts, port | |
| aesgcm | AES-GCM: the cipher every TLS 1.3 server must speak (processor's AES and carry-less multiply) | |
| charset | turns windows-1252, UTF-16 and damaged UTF-8 into clean UTF-8; reads encoding labels as browsers do | |
| shell | takes events (touch, time, size), keeps which screen shows, draws it; state | home, paint, text |
| home | a home screen: render and hit-test from one layout | paint, text |

## The host side

- `loader/pieces_jni.c` → `out/libtrough-pieces.so`: a tiny library with no C library dependency. Places a
  blob in executable memory, owns the call table, holds blocks at handles, and makes the calls.
- `src/com/trough/hot/Pieces.java`: discovers any `out/<name>.piece`, replays its recorded checks inside the
  app, and only then points callers at it. Watches the files: a changed blob is checked in the background and
  swapped in live; the old code stays mapped. Nothing about a particular piece is written there.
  `Pieces.keep` (started from `Main.runWith`) is a thread of its own that opens the library and polls once a
  second for as long as the process lives, window or no window; before 2026-11-11 11:35 the only poll hung off
  the chat window's timer and the open microphone, so nothing was adopted with the screen off.
- Users today: `NativeVoiceInput` (listen-step and voice-policy, each with the old Java rule beside the call as
  the fallback). The drawing pieces are reachable through `Pieces.paint` and the request files below; nothing
  shows them on the real screen yet.

## Working on a piece

    ./build.sh <piece>/reference.c out/<piece>.ref <entries...>      the reference build (also fills sockets on the bench)
    ./build.sh <piece>/impl.S     out/<piece>.<variant> <entries...> a candidate
    ./out/vectors record out/<piece>.ref out/<piece>.piece out/<piece>.vectors
    ./out/vectors check  out/<piece>.<variant> out/<piece>.piece out/<piece>.vectors
    ./promote.sh <piece> <variant>      checks it here, then copies it into place; the app re-checks and swaps
    ./rollback.sh <piece>               the previous entry in out/history.log, through the same checks

Looking at what drawing pieces produce, without anyone looking at the phone:

    ./out/render out <w> <h> out.rgba < commands         on the bench (see loader/render.c for the commands)
    echo "<piece> <entry> <w> <h> <colour hex> numbers..." > ~/.trough/piece-render    in the app → piece-render.png

`tools/font_table.py` and `tools/text_path.py` read TrueType outlines themselves (no font library).
`out/textbench` and `out/cachebench` time text. `out/audiobench <stem> <file> <out.raw>` decodes and times audio; `out/soundbench` runs convert and mix on raw files.

When a piece others call changes what it returns (font's widths, say), re-record and re-promote the callers too (page was, for kerning): their recorded checks ran against the old answers.

A promoted piece is three files that belong together: `<piece>.bin`, `<piece>.entries` and the seal `<piece>.pair` (their SHA-256 fingerprints). `promote.sh` removes the seal, replaces the two, and writes the seal last; the app runs nothing whose files do not match their seal. Never copy a `.bin` into place by hand.

Changing a description's meaning means: edit `intent.md` and `reference.c`, rebuild the reference, re-record,
rebuild the variant, promote. If the manifest or checks land before the matching code, the app keeps the
current code and says why.

## Measured so far (Pixel 7a, big core)

- sound-measures energy 4.6x gcc -O3, climbs 4.8x; byte search 12x a plain loop (22% behind libc); binary
  search 2.1x; paint a tie with gcc (memory-bound); a serial checksum a tie.
- A swap is one pointer store (about 0.1-2 µs); the checks before it take 0.2-6 s.
- A Java change to Trough costs a build of about 1-2 minutes; a change to a piece reaches the app in seconds.
- flac: sample-identical to the standard decoder on 21 files (levels 0-8, deep prediction); 20 s of stereo in 60 ms (about 300x real time; the standard tool takes 95 ms for the same file including writing it).
- jpeg progressive: 401 x 517 photo in 4.3 ms (ordinary: 2.4 ms); pixel-identical to the ordinary form of the same picture on 40 test pictures.
- hash: SHA-256 at 1,045 MB/s with the processor's instructions, 9.5x plain C (110 MB/s); OpenSSL's assembly: about 1,430 MB/s. `out/hashbench <stem> <entry> <MB>`.
- Text (re-measured 2026-11-11 with fill fast, font v3 with kerning): 8.6 µs a character filled every time at 16 px, 0.45 µs from the letter cache (0.29 before kerning: the pair lookup costs about 0.16 µs a character and has no fast variant yet). Earlier figures: 21 µs and 0.65 µs. (`out/cachebench <font> <fill> <cover> <font file> <out.rgba>`, `out/textbench <font> <fill> <font file>`.)

## An address in, a picture out (bench)

    python3 tools/fetch.py <address> <out.png> [text size]

url resolve/part/port → http request → tls with trust and Android's roots (or a plain socket for http) → http status/header/body → inflate → page → picture, following up to five redirects. Seen working on 2026-11-11: example.com, the first CERN page, www.wikipedia.org (after a 301), news.ycombinator.com, a 35 kB text file from gnu.org. Scripts missing from our font show as boxes; no styles, images or scripts in pages. When the reply is a picture (PNG, JPEG or GIF by its first bytes) the tool decodes it with the matching piece and scales it to fit with `image`: seen working on Wikipedia's logo (PNG), a 1 MB animated GIF from Wikimedia (first frame), and JPEG photographs from httpbin.org and gnu.org. upload.wikimedia.org answered 400 and 429 to two thumbnail and original requests (their policy for automated clients).

## Not done, and known gaps

- tls v3 (both ciphers; `begin` takes a fourth number: 0 offer both, 1 ChaCha20 only, 2 AES-128-GCM only; new `reset` entry) is live. Its recording catches 7 of 9 deliberate breaks: skipping the guard for a server with no certificate, and ignoring the handshake-signature answer, pass this recording (they failed v2's). Work on that was stopped by a safety check on 2026-11-11 and is not to be retried in that session. The code for both paths is unchanged from v2.
- build.sh refuses a piece in which one entry calls another (address-table reference).

- tls v2 is live: it checks the server through `trust` when the host passes roots and the time (`TLS_ROOTS=out/android-roots.der out/tlsbench ...`). Still missing: HelloRetryRequest, key update, our own closing notice, AES-GCM, revocation, a faster root lookup (4-30 ms a connection now), and nothing in the app uses it yet.

- Recorded checks, format 2 and 3: until 2026-11-11 an ordinary first entry got only 40 of the 6,040 calls (it was treated like check/migrate) and entry-line argument ranges were ignored. Fixed in `out/vectors`; cert, exchange, flac, hash, http, inflate, rsa, seal, sound re-recorded and their live builds still pass. Judge a piece's checks by breaking the code on purpose, not by the count.

- `out/vectors record` used to crash on a piece with a single entry (fixed 2026-11-11); the older recording forms (format 1) still need two or more.

- Nothing made of pieces is on the real screen; touch does not reach `home hit`.
- shell decides behaviour, but nothing in the app forwards real events to it or shows what it draws.
- page: its recorded checks use a one-paragraph page, so headings, lists, links, comments and character
  references are implemented but unproven. No comparison yet against a reference browser (Chromium is to be
  used only as a bench-side reference, never as a fallback).
- font: kerning from GPOS pair adjustment (v3; no script/language selection, no variation deltas); cmap format 4 only, composite glyphs unscaled, no mark positioning, no ligatures, no hinting, no bold or italic (the test font is variable; only its default instance is read).
- image: `smooth` is for shrinking, `stretch` (v3, bilinear, agrees with a Python model on 7 cases) for enlarging; the caller chooses. No faster variant of either yet.
- png: all depths, kinds and interlacing now read (live build `fast3`; test generator in png/checks/, needs netpbm). 16-bit samples are cut to their high byte; no gamma or colour-profile handling; an interlaced file is only shown once complete.
- jpeg: baseline and progressive (shared code in `jpeg/progressive.h`; live build is `fast3` = fast2.c with it; the older fast.c does not have it); 12-bit and arithmetic-coded files refused; colour planes are enlarged by repeating pixels, so edges of colour are blockier than a smoothing decoder's; damaged files decode to garbage rather than being refused (safely: nothing is written out of bounds).
- sound: `convert` agrees with an independent Python model on 27 cases; `resample` agrees with an independent Python model on 18 cases (sound/checks/soundcheck.py). Nothing carried between calls, so separate runs have a seam.
- flac: 16-bit only; escaped residuals are implemented but no fixture exercises them (the standard encoder does not produce them); right-side stereo and wasted bits are now in the recorded checks; the audio MD5 is not verified; whole file at once (no streaming or seeking); nothing plays it yet.
- gif: stateless, so showing frame k redraws frames 0..k (a playing animation wants a stateful variant); a frame with its own colour table has been checked once by hand (not in the recorded checks); 80 stills match giftopnm, 99 animation frames match a Python model of the intent fed by giftopnm's per-frame decoding. gifsicle's own flattening differs by design where the canvas is uncovered or cleared (it paints the background colour; this piece, like browsers, leaves it see-through).
- fill: every edge is tested on every sample row; an active-edge table would help large shapes.
- Secure connections: `tls` completes real TLS 1.3 handshakes (example.com, wikipedia, google) through `hash`, `seal`, `exchange`, but does NOT check the server's certificate, so it must not be used for anything that matters yet. RSA signature checking exists (`rsa`, 145 µs at 2048 bits). SHA-384/512 are in `hash` (v3, plain C, 234 MB/s against OpenSSL's 478). ECDSA on P-256 and P-384 exists (`ecdsa`, 0.9 and 1.2 ms a check, about ten and two times OpenSSL's), and certificates can be read (`cert`). The chain check exists (`trust`). Next: wire `trust` into `tls` (collect the certificates, check the chain and the handshake signature before accepting the server's proof, trim the offered signature kinds to the three we verify), with the host supplying the roots and the time. Then: X.509 parsing, the chain to a root, the name match. Also missing: AES-GCM, HelloRetryRequest, key update, close_notify on our side. `out/tlsbench <out dir> <ip> <port> <name>` drives it; faster variants of seal and exchange are still to write.
- No JavaScript, no styles. The host opens the connection and hands over the raw reply; http, inflate and page take it from there (run end to end on the bench against a real server).
- The font recordings refuse about two thirds of their cases (random sizes); rebalance toward valid ones.
- `piece-render` cannot hold a file or a cache at a live handle, so font and page output have only been
  viewed on the bench.

## One command per hand-written piece
`./byhand.sh <piece> "caption"` builds `<piece>/impl.S`, runs the recorded checks, the piece's own comparison, the secure
connection's checks and a real fetch with the piece standing in, then promotes, shows the card and publishes. It stops at the
first failure. Hand-written and live as of 2026-11-11: all 31 of 31 (font added last: same text widths and the same rendered page as the compiled build; not timed; jpeg added: same dots as the compiled NEON build on 2-megapixel photos in four styles, its transform now uses NEON by hand, and so does its colour step, and flat squares are filled directly: now level with the old compiled build on five 2-megapixel test pictures (some faster, some slower, within the noise of a warm phone); exchange, aesgcm, cert, trust, rsa, ecdsa, voice-policy, listen-step, home, cover, text, fill, image, gif, sound, flac, page, png and tls added; tls reached four live sites on both ciphers with the hand-written piece standing in; png same dots as the compiled one on real files (out/picbench), speed about level; the painters and image not timed; rsa and ecdsa level with the compiled ones; trust not yet timed against the compiled one; aesgcm about 1.7 times the compiled speed,
exchange level with it. exchange could gain from a dedicated squaring and a shorter inversion chain).

## Rough timing of every hand-written piece against what it replaced (2026-11-11 late, warm phone)
Replaying each piece's recorded checks through the old compiled build and the hand-written one (best of 3; the harness and the
pieces behind sockets are in both figures, so only large differences mean anything): none is clearly slower. Timed directly where
the replay looked worse: cert parses a certificate faster by hand (1.2 against 1.6 microseconds); gif gives the same picture as the
compiled build on the animation fixture, too small to time. Still not timed properly: gif on a large file, font drawing, page.
`out/picbench <piece> <file>` works for png, jpeg and gif.
Text and page, timed with `out/render` (2026-11-11 late): 400 lines of 58 letters drawn by the font piece take 550 ms by hand against
535 ms compiled (the fill piece behind its socket dominates both), same picture byte for byte; a short page laid out 20 times, 10 ms
against 11 ms, same picture. A long real page and a large GIF are still untimed.

## The host, and what runs end to end on the phone (2026-11-12)
`host/browse.c` (built as `out/browse`; `trough-browse`, `trough-ask` in ~/.local/bin) is everything a piece cannot do for itself:
the name lookup, the socket, the clock, the files. It drives the live pieces.
- `trough-browse <address> <out.png>`: url, http, tls with trust, inflate, page with font (or png / jpeg / gif with image).
  Wikipedia over a verified connection in about half a second.
- `trough-ask <key file> <model> <prompt file>`: llm writes the request, tls carries it to api.anthropic.com, http takes the
  reply out of its chunks, llm reads the words. Proven as far as a real refusal: a made-up key gets the server's 401
  `authentication_error`, which the llm piece reports as an error. A real answer needs a real key (not stored yet).
Hot reload: see RELOAD.md. The pieces' screen in the app: `PieceScreen.java` (written by the Gemini helper), shown over the
home panel while `~/.trough/piece-screen` exists; drawing confirmed only by the app staying up, touch not yet confirmed by a person.
The live screen (2026-11-12): `out/browse out --serve ~/.trough/screen.pic ~/.trough/screen.ev 360 720 <address>` keeps a page
open and redraws it into the shared picture; `echo "picture <pic> <events>" > ~/.trough/piece-screen` makes Trough's home panel
show it and write touches to the events file (remove that file to get the home panel back). Real drags scroll Wikipedia at
14 to 33 ms a redraw. The host is started by hand for now; nothing restarts it.
Since 2026-11-12 06:15 the screen bridge keeps the host running itself: in picture mode it starts the command in
`~/.trough/screen-host` (one argument a line) and starts it again within about two seconds if it stops (tried by killing it).
Its output goes to the app's cache as `screen-host.log`. To change the host: rebuild `out/browse`, then stop the running one.
Build the host: `gcc -O2 -pthread -o out/browse host/browse.c loader/piece.c`; it also needs `out/dom.asm` (`./build.sh dom/impl.S out/dom.asm begin ask`) and `out/document.js` (a copy of `dom/document.js`). Pictures in pages (2026-11-12): the page piece
lists them (`pictures`), a thread of the host fetches and decodes them one after another (png / jpeg / gif pieces), the image
piece scales each to its room, and the strips they sit in are drawn again as each arrives. Events the host takes: `d x y`,
`m x y`, `u`, `o address`, `g row`, `q`.
Typing (2026-11-12 06:37): `PieceKeys.java` (helper-written) lends the phone's keyboard when the host sets byte 32 of the picture's
head; keys arrive as `k <code>` events. Tap the address in the bar, type, go: an address opens, other words search
(html.duckduckgo.com). First real use: eight letters typed on the phone, the search opened, a result was tapped.
`trough-open <address or words>` types from the shell. Pages that need scripts (YouTube) come out nearly empty.
