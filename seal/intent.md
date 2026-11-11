# Seal

## What this is for
Locks a message so only the holder of the key can read it, and so any change to it is noticed. Every record
of a secure connection goes through this in both directions. This is ChaCha20-Poly1305 (RFC 8439), one of the
ciphers every TLS 1.3 server accepts, and the one that needs no special processor instructions.

## Entries
- **seal**(block, numbers: key handle, nonce handle, extra handle, message handle; how many; -) → writes the
  locked message followed by its 16-byte tag into the block from byte 64, and returns the message's length
  plus 16.
- **open**(block, numbers: key handle, nonce handle, extra handle, sealed handle; how many; -) → checks the
  tag; if it is right, writes the unlocked message into the block from byte 64 and returns its length
  (the sealed length less 16). If the tag is wrong, or the sealed bytes are shorter than a tag, returns -1
  and writes nothing.
Both return -1 if a handle is empty or not plain bytes (kind 2), the key is not exactly 32 bytes, the nonce
not exactly 12, the block is one of the inputs, or the result does not fit in the block.

## What the handles hold
- key: 32 secret bytes. nonce: 12 bytes that must never repeat under one key (the connection counts them).
- extra: bytes that are not locked but are covered by the tag (a record's header). May be empty.
- message / sealed: any length up to the block's room.

## Conventions
- The answers are those of RFC 8439 section 2.8: exactly one right output for every input.
- The tag is compared without stopping at the first difference, and nothing in the arithmetic branches on or
  indexes by secret bytes, so the time taken shows only lengths.
- No state; calls nothing. One call handles a whole message.

## Implementations and what was measured
- `reference.c` (live as v1): plain C, 266 MB a second sealing and opening on the Pixel 7a. OpenSSL's
  hand-tuned assembly does about 700 MB a second on the same phone; a variant using the processor's vector
  instructions is the next step.
- Agrees with the `cryptography` library (OpenSSL underneath) on 228 calls: sealing and opening at 59
  lengths around every block boundary, a flipped bit anywhere refused with nothing written, changed extra
  bytes refused, wrong key and nonce sizes refused; and the published example of RFC 8439 section 2.8.2
  (`seal/checks/check.py`).
