# flow [by Opus, 2026-11-13]: the field that everything morphs through
A field is a block of numbers, each with a value and a target. The model writes targets; `step`, called once per frame,
moves each value the given share of the way to its target (rate/65536), and sets it exactly to the target once within
about 5e-10. Answer: how many are still moving (0: the field is at rest, nothing needs drawing). No state of its own.
Verbs (drawing, layout, sound) read values, never targets, so every change the model makes appears as a morph.
