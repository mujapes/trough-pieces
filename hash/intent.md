# Hash

## What this is for
A fingerprint of any bytes: 32 bytes that change completely if a single bit of the input does, and that nobody
can aim at. Secure connections are built on it (every step of the handshake is hashed, and the keys are
derived with the keyed form), and it is how a download is checked against a published fingerprint. This is
SHA-256 and HMAC-SHA-256, the first pieces of Trough's own secure-connection stack.

## Entries
- **sha256**(block, numbers: source handle; how many; -) → writes the 32-byte SHA-256 of the bytes held at
  that handle into the block from byte 64, and returns 32. -1 if the handle is empty or not plain bytes
  (kind 2), the block is the source, or the block has no room for 32 bytes.
- **hmac_sha256**(block, numbers: key handle, message handle; how many; -) → writes the 32-byte HMAC-SHA-256
  of the message under the key, and returns 32. -1 as above for either handle. The key may be any length
  (one longer than 64 bytes is hashed first, as the standard says); it may be the same block as the message.

- **expand_label**(block, numbers: secret handle, label handle, context handle, length; how many; -) →
  writes that many bytes (1 to 255) of key material named by the label and context, derived from the secret,
  and returns the length. This is HKDF-Expand-Label of TLS 1.3 (RFC 8446 section 7.1): the label is given
  without its "tls13 " prefix, which the piece adds; label at most 249 bytes, context at most 255. -1 for a
  bad handle, a length out of range, or no room. (The other half of HKDF, "extract", is hmac_sha256 with the
  salt as the key.)

- **sha384**(block, numbers: source handle), **sha512**(block, numbers: source handle) → the 48-byte SHA-384
  or 64-byte SHA-512 of the bytes at the handle, written from byte 64; returns 48 or 64, or -1 as for sha256.
  Certificates signed with the larger curves and keys use these.

## Conventions
- The answers are those of FIPS 180-4 and RFC 2104: there is exactly one right output for every input.
- A block's bytes are those after its 64-byte header; its length is its size (bytes 16-23) less 64.
- Only the 32 bytes are written. No state; calls nothing. One call hashes the whole input (a form that takes
  the input in parts comes when the handshake needs it).
- Time taken does not depend on the contents of the key or message, only on their lengths.

## Implementations and what was measured
- `reference.c`: plain C, 110 MB a second on the Pixel 7a.
- `fast.c` (live): the rounds use the processor's SHA-256 instructions: 1,045 MB a second, 9.5 times the
  plain form. It needs a processor with those instructions (ARMv8 "sha2"; present on every core of this
  phone). OpenSSL's hand-tuned routine does about 1,430 MB a second on the same phone, so there is a further
  third to find.
- Both agree with Python's hashlib on 209 inputs of every length from 0 to 199 and around each block
  boundary up to a megabyte, on 110 key and message combinations for the keyed form, and on the published
  test values (`hash/checks/check.py`).

- `impl.S` (live, 2026-11-11): written by hand in ARM64, generated with its constants by a small script that computes them from their definition (3,744 bytes against 10,128 compiled). SHA-256 through the processor's instructions, SHA-384/512 in plain 64-bit arithmetic. First run failed recorded check 27 (a value kept in a register the round routine also uses); fixed, then all 6,040 recorded checks and the same 737 comparisons with Python pass. On one pinned core, MB a second, compiled then by hand: SHA-256 432 / 554, SHA-512 106 / 115. tls, trust and rsa pass their own checks with it underneath.
