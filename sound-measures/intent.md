# Sound measures

## What this is for
The always-on listener looks at the microphone a tenth of a second at a time and has to decide, cheaply,
whether someone is speaking. These are the two measurements it needs.

## Entries
- **energy**(samples, count) → the sum of the squares of the samples. The caller turns this into loudness.
- **climbs**(samples, count, threshold) → how many times the sound rises through the threshold: the number
  of positions i from 1 to count-1 where sample i-1 is at or below the threshold and sample i is above it.
  Speech climbs two or three times a second, syllable by syllable; wind and bumps about once.

## Conventions
- Samples are signed 16-bit, one channel. count may be zero or any positive number, not only whole blocks.
- energy returns a signed 64-bit number and must be exact for every possible input (no rounding, no overflow).
- climbs returns a 64-bit count. threshold is a signed 16-bit value passed as an integer.
- No state: the same input always gives the same answer. Nothing outside the arguments is read or written.
- The implementation calls nothing outside itself and may be replaced between any two calls.
