# RSA

## What this is for
Checks an RSA signature: proof that the holder of a private key signed exactly these bytes. Most certificate
authorities sign certificates this way, and many servers sign their handshake this way. First part of
checking that a secure connection's other end is who it claims to be. Verification only: nothing here is
secret, so nothing needs hiding in its timing.

## Entries (the block is not used)
- **verify_pkcs1**(-, numbers: modulus handle, exponent handle, signature handle, digest handle) → 1 if the
  signature is a valid PKCS #1 v1.5 signature of the message whose hash is the digest, 0 if not. The digest's
  length says which hash: 32 bytes SHA-256, 48 SHA-384, 64 SHA-512. (This is how certificates are signed.)
- **verify_pss**(-, the same numbers) → the same for RSA-PSS with SHA-256, a 32-byte salt and MGF1 with
  SHA-256; the digest must be 32 bytes. (This is how a TLS 1.3 server signs its handshake.)
Both return -1 for input that is not a usable key and signature at all: a handle that is empty or not plain
bytes, a modulus under 1024 or over 4096 bits or even, an exponent that is even, under 3 or over 4 bytes, a
signature not exactly as long as the modulus or not below it, a digest of another length.

## Conventions
- Numbers are big-endian bytes, as certificates hold them; leading zero bytes on the modulus are ignored.
- The answers are those of RFC 8017 (sections 8.2.2 and 8.1.2). The v1.5 form is checked by building the one
  correct padded value and comparing all of it, so no malformed padding is accepted.
- verify_pss calls hash sha256 through the call table (socket 14). No state.

## Implementations and what was measured
- `reference.c`: Montgomery multiplication with 64-bit limbs; 250 microseconds for a 2048-bit key.
- `fast.c` (live): the same with a quicker start (the constant 2^(128k) mod n by squaring instead of
  thousands of doublings): 145 microseconds at 2048 bits, 351 at 4096. OpenSSL takes about 28 at 2048: a
  dedicated squaring and assembly would close most of that.
- Both agree with the `cryptography` library on 448 cases: keys of 1024, 1032, 2047, 2048, 2049, 3072 and
  4096 bits, exponents 3 and 65537, three hashes, both paddings; every valid signature accepted, every
  flipped bit, wrong digest and wrong padding kind refused (`rsa/checks/check.py`).
