# Sound

## What this is for
The step between a decoder and the speaker. Music arrives at its own sample rate and channel count; the device
plays at one rate with two channels, and more than one thing may be sounding at once (music and the voice).
This piece converts a run of samples to the device's shape and mixes runs together.

Samples everywhere are 16-bit, little-endian, channels interleaved. A run of samples is plain bytes (kind 2)
at a handle; its length is the block's size less the 64-byte header.

## Entries
- **convert**(block, numbers: source handle, source rate, source channels, wanted rate, wanted channels,
  volume; how many; -) → writes the converted sound into the block from byte 64 and returns the number of
  samples written, counting every channel. Rates are in units of 25 Hz (44,100 Hz is 1764; 48,000 Hz is
  1920), from 1 to 7680. Channels are 1 or 2. Volume is 0 to 256, where 256 leaves the level alone.
  Returns -1 if a handle is empty or not plain bytes, a number is out of range, or the block is the source.
  Sound that does not fit in the block is left out (whole frames only).
- **mix**(block, numbers: source handle, volume, start low, start high; how many; -) → adds the source's
  samples, at that volume, onto the samples already in the block, beginning at sample start low + 32768 ×
  start high. Sums are held to -32768..32767. Returns the number of samples added to, or -1 as above or if a
  number is negative.

- **resample**(block, the same numbers as convert) → the same job with a filtered rate change: slower, and
  much cleaner. Use this for music; convert is for when speed matters more.

## How convert works (whole-number arithmetic, so every correct implementation gives the same samples)
- With F source frames, it makes floor(F × wanted rate / source rate) frames.
- Output frame i sits at source position i × source rate / wanted rate: k is the whole part, r the remainder
  (0 ≤ r < wanted rate). Its value in each source channel is
  floor((s[k] × (wanted rate − r) + s[k+1] × r + wanted rate / 2) / wanted rate), where s[k+1] is taken as
  s[k] at the last frame. (A straight line between neighbouring samples.)
- Channels: one to two repeats the sample; two to one is floor((left + right) / 2); otherwise unchanged.
- Volume: floor(value × volume / 256). The result always fits in 16 bits.

## How resample works (also whole numbers)
- The table in `kernel.h` (written once by `tools/sound_kernel.py`; fixed data from then on) holds one side of
  a smooth bump: 2049 weights, 256 steps for each sample of distance, out to 8 samples.
- Let wide be the larger of the two rates. For output frame i, with pos = i × source rate, every source frame
  j from floor((pos − 8 × wide) / wanted rate) + 1 to floor((pos + 8 × wide) / wanted rate) takes the weight
  kernel[|j × wanted rate − pos| × 256 / wide] (whole-number division; skipped if past 2048). Frames before
  the start or after the end count as the first or last frame.
- The value is floor((sum of weight × sample + total weight / 2) / total weight), held to 16 bits. Channels
  and volume then follow as in convert. Dividing by the weights actually used keeps a steady level exact.
- Lowering the rate stretches the bump (through wide), which removes the pitches the new rate cannot hold.

## Measured (single tones, 1 second)
- 10 kHz, 44.1 → 48 kHz: convert leaves false tones 20 dB below the tone and loses 1.5 dB of it; resample
  loses 0.01 dB with nothing measurable beside it.
- 18 kHz, 44.1 → 48 kHz: convert 6 dB; resample 40 dB, and the tone is 1.3 dB quiet (the bump starts to
  roll off there).
- 10 kHz, 48 → 44.1 kHz: convert 22 dB; resample 59 dB.
- 15 kHz into 22.05 kHz, which cannot hold it: convert folds it to 7.05 kHz at full strength; resample
  leaves it 92 dB down.
- 20 s of stereo, 44.1 → 48 kHz: convert 16 ms, resample 79 ms.

## Known limits
resample picks the nearest of 256 table steps without blending between them, and its bump is 8 samples wide:
a longer, blended one would be cleaner near the top of hearing. Nothing is carried between calls, so a long
sound converted in separate runs has a small seam at each join.

## Conventions
- Every read and write is checked against the blocks' sizes. No state; calls nothing.
