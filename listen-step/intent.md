# Listen step

## What this is for
Ten times a second the always-on listener gets a block of microphone sound. This piece keeps the listener's
sense of how loud the background is, and says whether the block stands out from it enough to be a voice.

## Entries
- **migrate**(state) → brings a state block up to this layout. A block of zeros (never used) becomes a fresh
  one; a version 1 block keeps what it learned and gains the new fields, cleared. Returns the layout version
  it leaves behind, or 0 if it does not recognise the block (which it then leaves untouched).
- **step**(state, samples, count, flags) → bit 0 set if the block is loud enough to count as voice; bit 1 set
  if the last second has the rhythm of speech; bit 2 set if the microphone hit its ceiling in this block (the
  peak piece reports 32700 or more), which is distortion no later step can undo.
  flags bit 0: the voice is playing through the earbud (the bar is higher, so its own sound is not taken
  for the user). flags bit 1: a piece of speech is being recorded (the background is learned more slowly,
  but still learned, so steady noise cannot hold a recording open; and the fine history is kept).

## State (512 bytes, owned by the host, little-endian; layout version 2)
| bytes | what | since |
| 0-3 | layout version (2) | 1 |
| 8-15 | background level, a double; starts at 0.004, never below 0.0005 | 1 |
| 16-23 | level of the latest block, a double: root of the mean square, with full scale as 1.0 | 1 |
| 24-31 | blocks seen, a 64-bit count | 1 |
| 32-39 | fine position: how many fine measurements have been written, a 64-bit count | 2 |
| 64-463 | fine history: 50 doubles, a ring; measurement k lives in slot k mod 50 | 2 |
| the rest | zero, reserved | |

Hosts hand every piece a 512-byte block from now on; version 1 code only ever touched the first 64.

## Uses
Through the call table: sound-measures energy (socket 0) for every loudness, peak (socket 2) for clipping.

## Conventions
- The piece keeps nothing between calls except what is in the state block. The host may swap implementations
  between any two calls and must call migrate once before the first step of a new one.
- Background: if the level is below it, the background moves halfway down to the level; otherwise it creeps up
  by 1% of the gap per block (0.3% while recording).
- Loud means: level above the larger of 3.5 times the background and 0.012, times 1.6 while the voice plays.
- Fine history: only while recording, each whole run of 320 samples in the block (a fiftieth of a second)
  adds one measurement, its level; a trailing part-run is ignored.
- Rhythm: take the largest value in the fine history as the top. Walking the ring from oldest to newest, count
  the places where one measurement is at or below 35% of the top and the next is above it. Two or more climbs
  is the rhythm of speech: a voice rises syllable by syllable, wind and bumps about once a second.
- Arithmetic is IEEE double, each operation rounded on its own (no fused multiply-add), so every correct
  implementation gives bit-identical state. Tests compare bits, not approximations.
