# Voice policy

## What this is for
The rules that shape how the hands-free voice behaves, kept out of Trough's Java code so they can be tuned
while the app runs. The user adjusts these by ear, often several times in one drive.

## Entries
Each takes a short list of 16-bit numbers. A number that is not supplied counts as 0 unless stated.
- **skip_ahead**(unsaid characters, clips waiting) → 1 when the voice is far enough behind that a new note
  should jump the queue, otherwise 0. Behind means unsaid + 70 × clips is at least 6000 (about six minutes of
  speech). It was 500, then 1500; both cut off answers the user had asked for, twice in one night, so skipping
  is now a last resort for a runaway backlog only.
- **duck_volume**(user is talking, microphone is open, chosen percent) → the voice's volume in thousandths.
  1000 unless the user is talking with the open microphone; then ten times the chosen percent, held to 0-100.
  A chosen percent below zero, or not supplied, means the default of 10 (30 was "kind of distracting").
- **filler_wait**(stock lines said in this silence, a step is running) → milliseconds of silence before the
  next stock line: 8000 before the first, 25000 after that (the user found frequent stock lines tiresome).
- **points_wait**() → milliseconds of silence before one of the agent's queued talking points is said: 1500 (2500 left gaps the user kept noticing).

- **join_wait**(words heard so far in this message) → milliseconds the open microphone waits, after the user
  goes quiet, before sending what it has heard. Anything said in that time joins the same message. 5000 for
  five words or fewer (a few words are usually the start of a thought: two messages in one night arrived as
  "we're going to need to" and nothing more), otherwise 3500.

## Conventions
- No state. The same inputs always give the same answer. Calls nothing outside itself.
- Inputs beyond those listed are ignored.
