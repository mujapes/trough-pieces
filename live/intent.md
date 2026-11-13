# live: the fluid foundation [design by Opus, 2026-11-13, for Fable's review]

User (a4748baf, f9af1ce1): not hot reload. One living memory that is written and run at the same time, in real time,
made for models to write software live. Everything we have is rebuilt on it.

## What it replaces
Hot reload kept two builds side by side and guarded each swap with seals, a replay of recorded checks and a 20-second
health trial. That is a release process. Fluid has no release: a write is live at the next call.

## The memory
- One in-memory file (memfd), mapped twice into the process: a **write view** (read+write) and a **run view**
  (read+execute) of the same pages. Android allows this route (loader/piece.c uses memfd today). The writer stores
  instructions through the write view; the same bytes are runnable through the run view at once. No copy, no load step.
- **Code arena**: append-only. A new version of a function is appended; nothing is overwritten, so every earlier
  version stays runnable and is the undo.
- **Cells**: a table of 8-byte addresses, one per named function. Every call goes through its cell (load + branch,
  two instructions). Flipping a cell is one release store (reload `take`/`back` already do exactly this).
- **State arena**: read+write blocks that belong to names, not to code versions. Code changes; state carries on. A new
  version that changes a block's layout gets a new block and reads the old one once (the old `migrate` idea, kept small).

## A write
1. The model sends a function's text (ARM64 assembly) to the writer.
2. Assembled (at first with `as`, tens of milliseconds; later our own assembler piece, to reach well under one).
3. Appended to the code arena through the write view; the instruction cache cleared for that range.
4. The cell flipped. Visible on the next call; the screen calls its draw cells every frame, so within ~16 ms.
The writer answers with the time taken. No seals, no replays, no trial.

## Safety: undo, not checks
- Each flip keeps the previous address (the ledger). A fault (bad access, bad instruction) inside the run view is caught
  by the runner's signal handler: the faulting address names the version, that cell is flipped back, and the call
  answers with an error. Only that function goes back, never the app.
- A function that runs too long is caught by a watchdog tick the same way.
- Recorded checks become optional, run by the model when it wants evidence, not a gate.

## Who reads
Everything calls through cells: the screen host's draw and input, the script engine's entries, Trough's own screen
parts. So a write anywhere shows at once wherever it is used.

## Rebuild order
1. Core: memfd arena with two views, cells, writer (`trough-live write NAME FILE.S` -> microseconds taken), fault undo.
   Machine code, with the smallest host for mmap and signals.
2. The background browser host runs on it: its draw and the engine entries become cells, so edits show live.
3. The script engine's pieces become cells (state = the world block, unchanged across writes).
4. Trough's own screen parts, so UI changes stop going through the Java rebuild.
5. Our own assembler as a piece, so a write is sub-millisecond end to end.
