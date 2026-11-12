# Hot reload: how a running piece is replaced

The foundation Trough is built on: any part can be replaced while everything keeps running, and a bad replacement
undoes itself. This is what exists, what each rule is for, and what is still missing.

## The unit
A piece is flat, position-independent machine code (`<piece>.bin`), a list of entry offsets (`.entries`), a plain
description (`intent.md`) and recorded checks (`.piece`, `.vectors`). It keeps no memory of its own: state lives in a
block the host owns, and other pieces are reached only through numbered sockets in a call table. So replacing a piece
is replacing what one socket points at.

## The steps of a swap, and who decides
1. **Admit** (`promote.sh`): the candidate replays the recorded checks on the bench. A failure changes nothing.
2. **Seal**: the code and its entry list cannot be replaced in one step, so they carry a seal, the SHA-256 of each.
   The seal is removed first and written last. Nothing loads files that do not match their seal.
3. **Keep the way back**: the build that is live is copied to `<piece>.prev.*` first.
4. **Take** (the app's keeper, every second, screen on or off): it sees the new seal, loads the code into fresh
   executable memory, replays the recorded checks again inside its own process, and only then points the sockets at
   it. Callers in flight finish in the old code; the old memory is not unmapped.
5. **Trial** (`tools/guard.py`): the promotion is on trial until the app reports the new size and then stays alive
   20 seconds. If the app's process dies in that time, or the app refuses the build, the previous sealed pair is put
   back the same way, and a card says so. Otherwise the trial ends: "settled" in `out/history.log`.

## State across a swap
A piece that keeps state has a `migrate` entry and a layout version in the first four bytes of its block. The new
code is handed the old block: it returns the version it leaves behind, or 0 if it does not recognise the block
(which it then must leave untouched, and the swap is refused). Rules: never reinterpret a field; new fields are
cleared; what was learned is kept. `listen-step` (versions 0, 1, 2) and `tls` are the worked examples.

## What a swap must never do
Run code whose files are mid-replacement (the seal); run code that fails its recorded checks (steps 1 and 4); block
the screen while checking (the keeper is its own thread; callers never wait on a lock); lose state (migrate); stay
on a build that kills the app (the trial).

## Missing, in order
1. The trial only notices death and refusal. A build that passes its checks, keeps the app alive, and is merely wrong
   in a way the checks do not cover is not caught. Wanted: a health entry or a comparison window against the build
   before, on live inputs.
2. Rolling back state: `migrate` only goes forward. A rolled-back piece meets a block in the newer layout and
   refuses it (safe, but what was learned is dropped). Wanted: keep the pre-swap block until the trial settles.
3. The decisions in steps 2 and 4 (does this pair match its seal; did the replay pass) are made by the host, in
   Java. They are to become a piece themselves (`reload`: `sealed`, later `replay`), so the loader is replaceable
   by the same rules.
4. Several pieces changing together (a caller and what it calls): today each swaps alone, so an interface change
   needs a build that accepts both. Wanted: a sealed set.
5. Sockets are global. A second table for a candidate would let it run beside the live one before taking over.
