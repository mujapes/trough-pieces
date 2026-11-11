# Trust

## What this is for
Decides whether a site's certificate is to be believed: it follows the certificate up through whoever vouched
for it until it reaches a root the phone trusts, checking every signature, date and permission on the way,
and that the certificate is for the site that was asked for. It also checks the server's own signature over
the handshake, which proves the server holds the certificate's key. Last part of knowing who a secure
connection's other end is.

## Entries (the block is not used)
- **chain**(-, numbers: name handle, roots handle, then 1 to 8 certificate handles, the site's first;
  argument: the time now, in seconds since the start of 1970) → 1 if the site's certificate is trusted.
  Otherwise the reason: -2 it does not cover the name; -3 a certificate on the path is not in date; -4 a
  certificate is used for something it does not allow (an authority not marked as one, or whose key may not
  sign certificates, or with more authorities beneath it than it permits; a site key that may not sign), or
  carries a critical rule this stack cannot follow; -5 no path to a trusted root (a signature that does not
  verify counts as no path); -1 unusable input.
- **signed_handshake**(-, numbers: certificate handle, scheme, content handle, signature handle) → 1 if the
  signature over the content verifies under the certificate's key with that TLS 1.3 scheme: 0x0804 RSA-PSS
  with SHA-256, 0x0403 ECDSA P-256 with SHA-256, 0x0503 ECDSA P-384 with SHA-384, the key being of the kind
  the scheme names. Anything other than 1 means no.

## The roots
Plain bytes at a handle: the trusted certificates one after another, each as stored (DER). The host builds
it from Android's own list. A root is trusted as it stands: only its dates are checked. A path ends at the
first root, in date, whose name is the issuer's and whose key verifies the signature.

## How the path is found
From the site's certificate upward, at most 8 steps: a root that signed the current certificate ends it;
otherwise the first certificate the server sent (in any order) that signed it becomes current, and must be
in date, marked as an authority, allowed to sign certificates, and within any limit on authorities beneath it.

A root's own limit on how many authorities may sit beneath it is honoured (version 2): a root that allows fewer than the
path has is passed over. Checked with made-up roots allowing 0, 1 and 2 beneath a chain of 2 (`trust/checks/check.py`); the
recorded checks have no such root, so they would not notice this rule being removed.

## Not done
Revocation is not consulted. Name constraints are not enforced (a certificate carrying them as critical is
refused). Signatures with SHA-1, Ed25519, P-521 or RSA-PSS in certificates are not accepted. Extended key
usage is not examined.

## How it uses other pieces
cert number, bytes, covers (sockets 23-25), hash sha256, sha384, sha512 (14, 21, 22), rsa verify_pkcs1,
verify_pss (26, 27), ecdsa verify (28). It hands them its own blocks through a table of its own that carries
the real sockets.

## Measured and checked
- The chains served by seven real sites on 2026-11-11 are trusted against Android's 120 roots, and refused
  under a wrong name, five years early or late, without their helpers, with another site's helpers, or with
  one bit of the certificate changed: 57 cases, all agreeing with the `cryptography` library's own verifier
  (`trust/checks/check.py`).
- Made-up authorities exercise each permission rule (`trust/checks/fixtures.py`).
- Eleven deliberate breaks, one for each rule, each fail the recorded checks.
