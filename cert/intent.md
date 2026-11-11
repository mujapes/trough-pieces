# Cert

## What this is for
Reads a certificate (X.509, in DER, held at a handle): the document in which an authority vouches that a
public key belongs to a site. This piece only reads: it hands out the parts that the signature pieces and
the chain check need, and says whether the certificate covers a site name. It decides nothing about trust.
Third part of checking who a secure connection's other end is.

## Entries
- **number**(-, numbers: certificate handle, which) → a fact about the certificate:
  0 how it is signed (1 RSA with SHA-256, 2 with SHA-384, 3 with SHA-512, 4 ECDSA with SHA-256, 5 with
  SHA-384, 6 with SHA-512; 0 some other way); 1 its key (1 RSA, 2 P-256, 3 P-384, 0 other); 2 whether it
  says it may sign other certificates (1 or 0); 3 valid from and 4 valid until, in seconds since the start
  of 1970; 5 how many more authorities may follow it (-1 if it does not say); 6 its key-usage bits as the
  certificate stores them (first byte, plus the second × 256; -1 if absent: 0x80 signing, 0x04 signing
  certificates); 7 whether it has a critical extension this piece does not know (1 or 0): such a
  certificate must not be accepted; 8 its version; 9 whether issuer and subject are the same bytes.
- **bytes**(block, numbers: certificate handle, which) → copies a part into the block from byte 64 and
  returns its length: 0 the signed part (what the signature is over); 1 the signature (RSA); 2 and 3 the
  signature's r and s (ECDSA); 4 and 5 the key (RSA modulus and exponent, or the curve point's x and y);
  6 the issuer's name and 7 the subject's, each as stored; 8 the serial number.
- **covers**(-, numbers: certificate handle, name handle) → 1 if the certificate's list of DNS names
  includes the site name, 0 if not. Letters match in either case; a trailing dot on the site name is
  ignored; an entry "*.example.com" covers exactly one more label (www.example.com, but neither
  example.com nor a.b.example.com). The older habit of looking at the subject's common name is not followed.
All return -1 if the handle is empty, the bytes are not a well-formed certificate, `which` is not listed, or
the part is absent or does not fit the block.

## Conventions
- Every length in the file is checked against what is left before anything is read; the signature kind
  named inside the signed part must be the one named outside.
- Extensions understood: basic constraints, key usage, alternative names. Passed over without complaint:
  extended key usage, policies, key identifiers, revocation addresses. Anything else marked critical sets
  fact 7 (name constraints among them: they are not enforced, so such a certificate is to be refused).
- No state; calls nothing.

## Measured and checked
- Agrees with the `cryptography` library on every fact and part of 144 real certificates: Android's 120
  trusted roots and the chains served by seven sites on 2026-11-11 (`cert/checks/check.py`).
- 1,200,000 damaged copies (cut short, bits flipped, bytes replaced), each placed against an unreadable
  page: refused or read, never a fault (`out/certfuzz`).
