# TLS

## What this is for
The secure connection a browser makes to a site: after it, everything in both directions is locked with keys
only the two ends hold. This piece is the client side of TLS 1.3 (RFC 8446). The host owns the socket and the
random numbers; the piece builds and reads every message, derives every key, and seals and opens every record.

Version 2 checks who the server is. When the host gives it the phone's trusted roots and the time, the piece hands the
server's certificates to the trust piece, and will not accept the server's proof unless the chain leads to a trusted
root for the name asked for and the server signed the handshake with that certificate's key. `unverified` in the state
is 1 until then and 0 after. A host that gives no roots gets a connection that is private but unidentified, and
`unverified` stays 1: nothing that matters may be sent on such a connection.

## The state block (the host lends 100,160 bytes, all zero, and calls migrate once)
The first 64 bytes are for the host to read: bytes 0-3 layout version (1), 4-7 stage (0 new, 1 hello sent,
2 handshake keys, 3 connected, 4 closed by the server, 5 failed), 8-11 bytes to send after the last call,
12-15 plain bytes produced by the last feed, 16-23 the state's size, 24-27 input bytes the last feed used,
28-31 unverified, 32-35 why it failed (a TLS alert number, or the server's; 42 when the server was not
believed), 36-43 where in the state the server's certificate message is and its length, 44-47 the trust piece's
answer (1, or its reason: -2 name, -3 dates, -4 not allowed, -5 no trusted root, -6 handshake signature).

## Entries
- **migrate**(state) → sets up an all-zero state. Returns 1.
- **begin**(state, numbers: seed handle, name handle, out handle) → the opening message. seed: exactly 96
  fresh random bytes (32 for the hello, 32 the exchange secret, 32 a session label). name: the site's name,
  1 to 253 bytes. Writes one record into the out block from byte 64 and returns its length; -1 if the state
  is not new or a handle is wrong.
- **feed**(state, numbers: in handle, out handle, plain handle, roots handle; argument: the time now in seconds since 1970) → bytes that arrived from the server (the in
  block's size says how many). Takes as many whole records as are there and leaves the rest: the host keeps
  the unused tail and adds what arrives next. Bytes to send back go to the out block, plain data from the
  server to the plain block; their lengths are in the state. Returns the stage, or -1 once failed.
- **send**(state, numbers: plain handle, out handle) → seals plain data into records (at most 16,384 bytes
  each) in the out block; returns the number of bytes to send, or -1 if not connected or there is no room.

## What it speaks
- One cipher (ChaCha20-Poly1305 with SHA-256) and one exchange (X25519): every TLS 1.3 server must accept
  X25519, and nearly all accept this cipher. A server that insists on another, or asks to start over with
  other settings (HelloRetryRequest), fails cleanly.
- The server's proof (Finished) is checked before anything is sent or accepted under the final keys. A
  record that does not open, or a proof that does not match, fails the connection for good.
- Messages after the handshake (session tickets) are passed over. Key updates, client certificates, early
  data and resumption are not done.

## How it uses other pieces
Through the call table: hash sha256, hmac_sha256, expand_label (sockets 14-16), seal seal, open (17-18),
exchange public, shared (19-20). It hands them blocks of its own by passing a small table of its own with
those blocks at handles 1-4: a piece may do that for pieces that call nothing themselves.

## Measured and checked
- Against a local OpenSSL-backed server and against example.com, www.wikipedia.org and www.google.com
  (2026-11-11): handshake completes and a page comes back. The pieces' share of a handshake is 0.5-1.3 ms.
- An independent Python derivation of the handshake keys (tls/checks_badproof.py) opens the captured
  session's records.
- Recorded checks replay a captured local session: whole, cut short, with a flipped byte, with the wrong
  seed, and with only the server's proof wrong (forged with the session's own key). Three deliberate breaks
  (skipping the proof check, accepting a record whose tag fails, a wrong key label) each fail the checks.
- Version 2 (2026-11-11): verified handshakes with example.com, www.google.com, www.wikipedia.org and github.com
  against Android's 120 roots; refused with the clock in 2031 (-3) and with a root list that lacks the server's
  root (-5). The check costs 4 to 30 ms a connection today, most of it walking the root list naively.
- Recorded checks now also replay: a session whose only fault is the server's signature, one whose only fault
  is its proof, and one where the server shows no certificate at all but a correct proof (all forged with the
  session's own keys, `tls/checks_badproof.py`). Seven deliberate breaks each fail the checks.
- Only the three signature kinds the trust piece verifies are offered.
