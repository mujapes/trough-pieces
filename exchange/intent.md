# Exchange

## What this is for
Lets two sides that have never met agree on a secret while everything they send is overheard. Each makes a
random secret, sends the public value made from it, and combines its own secret with the other's public
value: both arrive at the same 32 bytes, and a listener cannot. Every TLS 1.3 handshake starts this way.
This is X25519 (RFC 7748).

## Entries
- **public**(block, numbers: secret handle; how many; -) → writes the 32-byte public value for that secret
  into the block from byte 64 and returns 32.
- **shared**(block, numbers: secret handle, their public handle; how many; -) → writes the 32-byte shared
  secret and returns 32. If the result is all zeros (the other side sent one of the few values that give
  the same answer for every secret), returns -1 and writes nothing: the connection must be abandoned.
Both return -1 if a handle is empty or not plain bytes (kind 2), a value is not exactly 32 bytes, the block
is one of the inputs, or the block has no room for 32 bytes.

## Conventions
- The answers are those of RFC 7748 section 5: the secret is clamped as it says (lowest 3 bits and the top
  bit cleared, the next-to-top bit set), and the top bit of the other side's value is ignored.
- Numbers are held as five 51-bit parts modulo 2^255 - 19. The same sequence of operations runs whatever
  the secret is: 255 steps of the ladder, each choosing between its two running points by masking, never by
  branching or indexing. Time taken shows nothing about the secret.
- No state; calls nothing. Making the random secret is the host's job.

## Implementations and what was measured
- `reference.c` (live as v1): plain C with 128-bit products: 175 microseconds for either entry on the Pixel
  7a (about 5,700 a second). OpenSSL's tuned routine takes about 55 microseconds. A handshake needs two, so
  this costs a third of a millisecond per connection; a dedicated squaring and a shorter inversion chain
  are the obvious gains.
- Agrees with the `cryptography` library on 300 calls (random secrets and public values, all-zero and
  all-one secrets, public values with the top bit set), with the three published values of RFC 7748, and
  refuses the four zero-giving points tried (`exchange/checks/check.py`).
