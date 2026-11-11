# AES-GCM

## What this is for
The second cipher for the records of a secure connection, beside ChaCha20-Poly1305 (the seal piece). The TLS
1.3 standard says every server must support AES-128-GCM, and only should support the other, so this is the
one that guarantees agreement with any server. AES-GCM (NIST SP 800-38D), with a 16- or 32-byte key.

## Entries
The same as the seal piece, with the same answers and refusals: **seal**(block, numbers: key handle, nonce
handle, extra handle, message handle) and **open**(block, numbers: key handle, nonce handle, extra handle,
sealed handle). The key is exactly 16 bytes (AES-128) or 32 (AES-256); the nonce exactly 12; the tag 16.
open checks the tag first and writes nothing if it is wrong.

## Conventions
- The answers are those of the standard: one right output for every input.
- The tag is compared without stopping at the first difference. No state; calls nothing.

## Implementations and what was measured
- `reference.c`: the meaning, in plain C, with the substitution table worked out from its definition rather
  than typed in. 4 MB a second, and its table lookups depend on secret bytes, so it is never the live one.
- `fast.c` (live): the cipher and the field multiplication done by the processor's own instructions (ARMv8
  "aes" and "pmull"; present on every core of this phone), four blocks in step: 500 MB a second, 125 times the
  plain form and about twice the seal piece. Nothing is indexed by a secret. OpenSSL's assembly does about
  1,370 MB a second: wider interleaving and folding several blocks per multiplication would close more.
- Both agree with the `cryptography` library on 232 calls (59 lengths around every block boundary, both key
  sizes, tampering refused with nothing written, changed extra bytes refused, wrong sizes refused), and on a
  published key and nonce (`aesgcm/checks/check.py`).
