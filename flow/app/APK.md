# The new Trough: one install, then only Flow [plan by Opus, 2026-11-13, user a3810320; for Fable's review]
User: rebuild the Trough app itself in machine code around Flow. One new APK, installed once; every later change is a
piece written into the running Flow memory, never another install.

## Shape
- APK with no Java of ours: Android's own NativeActivity (android:hasCode="false") loads one small library, `libflow.so`.
- `libflow.so` is the Flow core in ARM64: it takes the window (ANativeWindow) and the input queue from Android, makes the
  arena (memfd, write view and run view), the cells and the field, and from then on only does three things each frame:
  steps the field, calls the cells that draw into the window's buffer, and turns touches and keys into field writes and
  events for the cells. It imports only Android's system interfaces (libandroid, liblog, the kernel); no other code.
- Everything else arrives as records on a stream file in the app's own storage (reload's record format, judged by the
  `reload` piece): new verbs, the browser engine, the script engine, the keyboard, the chat. The core appends each record
  through the write view and flips its cells: live at the next frame, morphing through the field, no restart.
- Writer: from the Debian userland (`trough-flow verb`, later the models directly) by appending records to the stream.
- Net: a faulting verb's cell goes back and answers -1 (as in flow/core.S and browse.c today).

## Order
1. libflow.so + manifest: a window filled by one verb from the stream; touch moves a field value. Build the APK on the
   phone (aapt2/d8-free: no dex), sign with a local key, the user installs it once beside the current Trough.
2. Text: the font piece as a verb; the field drives layout.
3. The browser host's jobs (fetch, tls, page, image pieces) as cells; the background browser inside the new app.
4. Input: the keyboard as verbs; the prompt goes to the models (llm piece) from inside the app.
5. Chat/agent view; then the old app is retired.

## Trough OS: recovery first (user dd7e5c9f / f0b2179f, 2026-11-13) [by Opus]
Name: Trough OS. Built like an operating system. Its first layer is a recovery state (like a BIOS): what everything
falls back to on any error; a light file system with a command line; and access to the model APIs so Claude Code or
Codex instances can be run to repair things. Plan:
1. The core falls back to recovery.bin (not the built-in band) when a boot crashes or is missing: one more install,
   the last one planned, because that fallback must live in the fixed core.
2. recovery verb: text console with our keyboard; commands: ls, cat, write, rm over the app's own folder (a light file
   system), load VERB (start an app verb), log.
3. Models from recovery: the llm, http and tls pieces (already machine code) as cells, so a prompt typed in recovery goes
   to a model API with no outside code. Running Claude Code itself needs the Linux userland, which lives in Trough's app:
   after the merge into Trough, recovery can start it there.
