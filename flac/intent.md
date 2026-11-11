# FLAC

## What this is for
Trough's first audio decoder: music from a file to samples. FLAC is the lossless music format, so every sample
has exactly one right value and the decoder can be checked exactly. (Lossy formats such as AAC and Opus, which
streaming uses, are later and larger pieces.)

## Entries
- **info**(block, numbers: flac handle, which; how many; -) → a fact from the stream's header: which 0 the
  sample rate, 1 the number of channels, 2 bits per sample, 3 the total number of samples per channel (0 if
  the file does not say). -1 if the handle is empty, the bytes are not FLAC, or which is not 0 to 3. The block
  is not used.
- **decode**(block, numbers: flac handle, scratch handle; how many; -) → decodes the whole stream into the
  block from byte 64 as 16-bit little-endian samples, channels interleaved (left, right, left, ...). Returns
  the number of samples written counting every channel, or -1 if the file is not one this piece can read, is
  damaged (every frame's two checksums are verified), or the result or the working room does not fit.

## What it reads
- 16 bits per sample, one or two channels, any sample rate and block size; all subframe kinds (constant,
  verbatim, fixed prediction of order 0 to 4, linear prediction up to order 32); both residual codings,
  including escaped partitions; all three stereo arrangements. Other bit depths and more channels are refused.
- Metadata other than the stream header is skipped. The MD5 of the audio is not verified.

## The blocks
- The file is plain bytes (kind 2) at a handle. The scratch block (kind 5) is working room for one frame:
  at least 64 + 8 × the largest block size × channels bytes. The block decoded into is any host block whose
  header gives its size in bytes 16-23.

## Conventions
- Every read is checked against the file's size and every write against the room. No state; calls nothing.
