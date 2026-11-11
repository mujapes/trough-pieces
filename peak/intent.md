# Peak

## What this is for
Tells how close a block of sound came to the loudest value the microphone can report, so the listener can
notice clipping (the user's phone microphone hit full scale in the car, which no filter can undo).

## Entries
- **peak**(samples, count, unused) → the largest absolute value among the samples, 0 for an empty block.

## Conventions
- Samples are signed 16-bit. The answer is between 0 and 32768 (the absolute value of -32768 is 32768).
- No state; nothing outside the arguments is read or written; calls nothing outside itself.
