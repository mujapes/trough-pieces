# ECDSA

## What this is for
Checks an elliptic-curve signature: the other kind of proof, beside RSA, that the holder of a private key
signed exactly these bytes. Most large sites' certificates, and many certificate authorities, sign this way.
Second part of checking who a secure connection's other end is. Verification only: nothing here is secret.

## Entry (the block is not used)
- **verify**(-, numbers: curve, public x handle, public y handle, r handle, s handle, digest handle) → 1 if
  (r, s) is a valid signature, under the public key (x, y), of the message whose hash is the digest; 0 if
  not. curve is 256 for NIST P-256 or 384 for P-384.
  -1 for input that is not a usable key and signature at all: another curve number, a handle that is empty,
  not plain bytes, empty or over 80 bytes, a number too large for the curve, or a public key that is not a
  point on the curve.

## Conventions
- Numbers are big-endian bytes of any length that fits, as certificates hold them (leading zeros or none).
- The answers are those of FIPS 186-4 section 6.4: r and s must each be from 1 to n - 1 (otherwise 0); the
  digest's leftmost bytes, as many as the curve's size, are taken as a number; the signature is valid when
  the x coordinate of (digest/s) G + (r/s) Q, reduced modulo n, equals r. A result at infinity is invalid.
- The curve constants (`curves.h`) are written by `tools/curve_table.py`, which checks each against an
  independent library first.
- No state; calls nothing. The digest is made by the caller (hash sha256 or sha384).

## Implementations and what was measured
- `reference.c` (live as v1): one generic routine for both curves (Montgomery multiplication, Jacobian
  points, both multiplications in one ladder): 886 microseconds on P-256 and 1,177 on P-384. OpenSSL takes
  about 92 and 540. P-256 has a dedicated fast reduction that this does not use, and each call sets up its
  constants afresh; a certificate chain needs two or three of these, so today it costs about 3 ms.
- Agrees with the `cryptography` library on 882 cases over both curves: valid signatures (including keys 1,
  2 and n - 1, digests longer and shorter than the curve, numbers with leading zeros added or dropped, and
  the mirror signature) accepted; a changed digest, r, s or key refused; r or s of 0 or n refused; a key off
  the curve reported as unusable (`ecdsa/checks/check.py`).
- `fast.c` (live): the same arithmetic compiled once per curve with the number of limbs fixed (`core.h`, written out of
  reference.c by the same text): on one pinned core 924 to 560 microseconds on P-256 (1.65x) and 2,140 to 1,843 on P-384
  (1.16x). Agrees with the library on the same 882 cases. A whole certificate chain gains only 0-20%, because chains are
  mostly signed on P-384. Still to try, in order of expected gain: two bits of both numbers per step (fewer additions),
  a shorter inversion, a dedicated squaring, and P-256's special prime.
- `fast2` (live, 2026-11-11): the same per-curve build with the final sum taken two bits of each number per step (a table
  of iG + jQ, i and j from 0 to 3): 528 microseconds on P-256 and 1,751 on P-384 on the same pinned core (924 and 2,140 for
  the reference that morning). Forcing the multiplication inline gave P-256 another 18% but tripled the piece to 91 kB for 5%
  on P-384, and was not kept. A multiplication of two 384-bit numbers costs about 235 ns here, so what is left is doing fewer
  of them: a shorter inversion, a dedicated squaring, signed digits.
