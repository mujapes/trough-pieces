# script: where the work stands (read this first when picking it up)

Written 2026-11-12 for a fresh session. Plan and design: `intent.md`. Build: `./build.sh script/impl.S out/script.asm <entries>`
from `trough-lab/pieces` (impl.S only includes the part files). Macros and labels share one namespace across the parts, and
macro names must not be instruction names (STR clashed; it is STRV).

Done and tested:
- `lex.S` + `tokens.S` (stage 1): `checks/words.py out/script.asm` → 413 scripts, 0 wrong.
- `num.S` (number to text, exact): `checks/numbers.py out/script.asm` → 2637 numbers, 0 wrong. Test entry `numtext`.
- `world.S` (memory layout, w_begin, w_alloc, w_string, w_out): used by numtext, so partly exercised.

Written, assembles, NOT yet run:
- `values.S`: v_truthy, v_number, v_text_number, v_same_text, v_strict, v_loose.
- `machine.S`: v_text, v_join, v_int32, m_run and 43 instructions (OP_* at its top), dispatch table m_table.

Not written:
- `compile.S` (empty file): words → instructions. One pass, precedence climbing. Stage 2 scope: var/let/const as globals (no
  block scope yet), expression statements, if/else, while, do-while, for(;;), break, continue, blocks; literals, names,
  unary - + ! ~ typeof void, ++ --, all binary operators, ?:, assignment and compound assignment to names, comma,
  `console.log(...)` as OP_PRINT. Constants go in the world's constant table, globals in the global table (name, value).
  The lexer's registers are x20-x28 and d8; the machine's are x21-x26; they are never live at the same time.
- `entries.S` has only begin and numtext: add load (copy source into the world, compile), run (m_run with the step
  allowance in x25), text (hand back and clear W_OUT), error.
- Then `checks/run.py`: each small program through our engine (out/render, world block kind 6 of 1.2 MB+) and through
  `qjs` and `node`; outputs must be the same text.

Known gaps to keep honest: strings are bytes (UTF-8), not UTF-16 units; `**` only for whole powers; huge-quotient `%`;
number literals beyond 19 digits or exponent 22 are near, not exact; `let` is not block scoped.
