# script: where the work stands (read this first when picking it up)

Written 2026-11-12 for a fresh session. Plan and design: `intent.md`. Build: `./build.sh script/impl.S out/script.asm <entries>`
from `trough-lab/pieces` (impl.S only includes the part files). Macros and labels share one namespace across the parts, and
macro names must not be instruction names (STR clashed; it is STRV).

Done and tested (2026-11-12, second session):
- `lex.S` + `tokens.S` (stage 1): `checks/words.py out/script.asm` → 413 scripts, 0 wrong.
- `num.S` (number to text, exact): `checks/numbers.py out/script.asm` → 2637 numbers, 0 wrong.
- `compile.S` (words → instructions, one pass; its head comment says how), `values.S`, `machine.S`, and the entries
  `load`, `run`, `text`, `error` in `entries.S`. Build:
  `./build.sh script/impl.S out/script.asm begin tokens numtext load run text error`
- `checks/run.py out/script.asm` runs every `checks/programs/*.js` through ours, `qjs` and `node` (node's console habit of
  printing -0 is evened out). 11 programs, 1171 lines. Right: first, flow, strings, numbers, unary,
  pairs0-2 (30 values × 30 values × 22 operators), remainder (exact long division, m_fmod).
  `run.py out/script.asm file.js -v` shows our output and error for one file.
- `text` and `error` entries are written but only `error`'s data (W_ERR, line, column) has been read back by run.py; the
  entries themselves have not been called by a check yet.

Later the same day: `literals.js` and `powers.js` now pass too (**11 of 11, 1171 lines**). Long number words are read exactly
(`n_exact` in `lex.S`: limbs on the stack, steps of floor division, round half to even, the smallest numbers included).
Whole powers are correctly rounded on the tested cases (`PAIRMUL` in `machine.S`: each product with its own miss, by fused
multiply-add). Powers that are not whole still give NaN (Math library, stage 6).

Stage 2 gaps not yet covered by any program (write the program first, then fix):
- a name never declared reads as undefined instead of raising ReferenceError (errors are stage 5); `typeof` of one is right.
- `let`/`const` are globals: no block scope, no dead zone, assigning to a const is allowed.
- strings are bytes (UTF-8), not UTF-16 units; comparison of text is by bytes (differs from the language only beyond U+FFFF
  against U+E000-U+FFFF).
- labelled break/continue, `in`, `instanceof`, `delete`, templates, patterns, big integers: refused as "not made yet".
- `load` starts the instructions afresh each time (globals stay); several scripts in one page need appending.
- nesting deeper than 400 is refused (C_DEEPEST) so the phone's stack cannot overflow.

Stage 3, first part, done (third session, same day): `functions.js` passes (12 of 12 programs, 1186 lines). Declarations (hoisted:
each scope begins with a jump to a block at its end that makes them, `c_hoist`), function expressions (named ones can call
themselves, OP_CALLEE), arrows (`c_peek_name`, `c_peek_paren` look ahead), calls, `return`, closures, recursion.
How it works, in short (details in the comments at the top of `machine.S` and above `c_function`, `c_scan_block`):
- a function's body is read through once before it is translated (`c_scan_block`): finds its declared names and whether it has
  inner functions. With none, its variables stay on the machine's stack; with some, they live in a heap scope (flag 1 in its
  plan) so inner functions keep them. Names resolve at translation time to OP_GETL slot / OP_GETUP hops slot / OP_GETG.
- assignment: `c_lvalue` returns the reading instruction's bytes, `c_store` writes the matching store (read op + 1).
- the world's head is 512 bytes now (W_FP, W_LOCALS, W_ENV at 256..).

Default parameters done (fourth session, 2026-11-12): `defaults.js` passes (**13 of 13 programs, 1191 lines**). In the
parameter list a default is stepped over (`c_skip_default`, after `c_scan_expr` notes inner functions); `c_defaults` goes back
to the first parameter once the body has been scanned and writes, per default: read, compare with undefined, work out, store.
While it does, only the parameters are visible (R_COUNT is lowered), so a default cannot see the body's variables; a named
function expression's own name is hidden there too (soft spot). Rest parameters wait for arrays.

**Stage 4, first part, done** (fourth session): `objects.js` passes on its first complete run (**14 of 14 programs, 1207 lines**).
New file `objects.S` (its head comment gives the heap layout: every object, array and function starts with kind, prototype,
properties; the instructions OP_OBJECT..OP_DUP2 are described beside their code). What works: object and array literals
(names, strings, numbers, computed keys, shorthand names, short methods), `o.name`, `o[key]`, assignment and `+=`, `++` on
both, array items and `length` (read and set), string `length` and `s[i]`, method calls with `this` (OP_CALLM; the call record
is eight places now), `new` with a lazily made `prototype`, prototype lookup, arrows keeping the `this` they were made under.
How the translator does it: `c_member` writes OP_GETP/OP_GETE and marks it as the last read (F_LV); `c_lvalue`/`c_store` then
treat it like a variable, `c_lvdup` doubles the object (and key) for read-then-store, `c_method` turns a property read just
before `(` into a call on the object. `c_scan_meth` spots short methods during the advance read so the outer function keeps
its variables in the heap.
Not made yet in stage 4 (each refused or noted): shapes (properties are searched in order), `&&=`-style assignment on a
property, spread, holes in array literals, getters and setters, classes, destructuring, `for..in`/`for..of`, `in`, `delete`,
`instanceof`, templates, `a["0"]` as item 0 (a text key on an array is a named property), item numbers of 16 million and up,
printing an array or object (prints [object Object]; arrays should print their items joined), Object.prototype and
Function.prototype (a literal's prototype is null), a short method whose name is catch/for/if/switch/while/with inside a
function, rest parameters and `arguments` (now possible: arrays exist).

Second part (fourth session): `rest.js` passes (**15 of 15 programs, 1214 lines**). Rest parameters (plan flag 4: `m_call`
pads, then gathers the arguments from the last parameter on with `a_from`), `arguments` (plan flag 8 and the variable's number
from bit 16 up: a real array of all the arguments, stored when the call begins; inside an arrow it wrongly means the arrow's
own), `in`, `instanceof` (both in `c_binary`, binding as comparisons; no "no in" rule yet, wanted before `for..in`),
`delete o.p` / `delete o[k]` (an array's item just becomes undefined), arrays as text (`a_text`, items joined by commas).
Still open from the list above: shapes, `&&=` on a property, spread, holes, getters and setters, classes, destructuring,
`for..in`/`for..of`, templates, `a["0"]`, printing through console.log as the engines do, Object.prototype.

Third part (fourth session): `each.js` passes (**16 of 16 programs, 1221 lines**). `for (name in v)` and `for (name of v)`
(`c_peek_each`, `s_each`; OP_KEYS, OP_ITER, OP_FORNEXT at the end of `objects.S`: the loop keeps an array and a place on the
stack). `for..of` takes arrays and strings only (iterators come with symbols); the loop variable must be a plain name.
One check was changed, not passed: looping over "héllo" gave 6 characters, not 5, because strings are still bytes (the
stage 2 gap above); the program now uses "hello". That gap now shows in `length`, `s[i]` and `for..of`: do UTF-16 strings soon.

Strings are units now (fourth session): `unicode.js` passes (**17 of 17 programs, 1226 lines**), so the "strings are bytes"
gap above is closed. New file `strings.S`: a string's first word is how many units (low 32 bits) and whether they are wide
(bit 32); one byte a unit when none is past 255, else two. `w_text` reads UTF-8 into units, `w_unit` makes a one-unit
string, `w_outs` prints as UTF-8, `s_copy` joins across widths. `STRV` gives the unit count; a routine that walks a string
must look at the width itself (v_join, m_order, o_keyeq, the item read in `objects.S` do). String literals are still built
as UTF-8 by `c_string` and then remade by `w_text` when they hold anything past ASCII. Left: `for..of` over text goes unit
by unit (a pair should stay together); global variable names past ASCII are compared as raw bytes (consistent, not units).

**Next, still stage 3:** `this` (undefined in plain calls until objects exist), the `arguments` object (needs arrays: with stage 4),
rest parameters and patterns (refused as "not made yet" in `c_function` label 31), a function's text for printing (prints as
[object Object] now), the name field of a plan (left undefined). Then stage 4: objects and arrays (shapes, property access,
`new`, methods and `this`), which is where real page scripts start to run.
Known soft spots: `c_scan_block` misses declared names that are contextual keywords or patterns (they are declared when met
instead, fine unless an inner function written earlier uses them); a template holding an arrow inside an arrow's expression
body would not be seen by `c_scan_expr` (templates are not made yet); recursion depth is bounded by the stack share (about a
thousand frames), reported as "RangeError: the stack is full"; every call of a function with inner functions takes heap that
is never given back until stage 7.
Registers: word reader x20-x28 and d8; translator's frame at x29; machine x20-x28 (x20 call record, x27 variables, x28 scope).

**Fifth session (2026-11-12 evening): templates and spread done: 19 of 19 programs, 1243 lines.** Read `script/MAP.md` first
(made by `tools/scriptmap.py`: every routine with a line about it, instruction and punctuation numbers; run the tool again after
adding routines) instead of the `.S` files. Templates: `c_template` in `compile.S` (the reader gives the whole template as one
word; the translator sends the reader back in for each `${}`; pieces are joined with OP_ADD, so an object with its own valueOf
would differ; tagged templates and `String.raw` not made). Spread: `c_args` (shared by calls, `new` and console.log) and
`c_array`: from the first `...` on, the items go into an array (OP_APPEND, OP_SPREAD), and a call takes it apart again
(OP_APPLY + which call: `m_call_n`, `m_callm_n`, `m_new_n`, `m_print_n`). Spread takes arrays and strings only. Holes in array
literals (`[1,,2]`) still refused; object spread not made.
Destructuring done (sixth unit, same evening): **20 of 20 programs, 1250 lines.** `c_pattern` in `compile.S` (declare or assign
mode; targets may be names, properties or patterns; holes, defaults, array rest by OP_TAIL, computed keys). The value comes first
at run time though the pattern's text is first: its instructions are written, jumped over, and jumped back to (`c_destructure`
for `var [..] = v` and `[..] = v`; the same in `c_defaults` for parameters and `s_each` for loop heads). A pattern parameter is a
nameless variable (`c_hidden`); the names inside are declared by translating the patterns once with the instructions thrown
away (c_function label 5), so a function written inside a parameter default is translated twice (harmless, wasteful).
Not made: object rest `{...r}`, object spread, a rest parameter that is a pattern, patterns in catch.
Next: classes, getters and setters, then shapes. Ask the Gemini helper for the check program first (it has been right twice).
Help that saves usage: GitHub Actions (`../pieces-repo`, public, pushes with `trough-gh` credentials; `ci/run.sh` now builds
the engine and runs `checks/run.py` there) and the Gemini helper for drafting check programs
(`trough-model-helper ask gemini-auto --prompt-file F`; the reply is JSON, the text is in `.text`; `/tmp/gtools/split.py` shows
how to split it). A random program generator for overnight differential fuzzing was asked of Gemini (`/tmp/gem/out2.txt`); if it is gone, ask again.
CI note: the runner's qjs is older and differs from node on literals.js and numbers.js; `run.py` now counts a program wrong only
when ours differs from node, and prints a note when only qjs differs. The generator request to `gemini-auto` failed once (likely
its 180 second limit); asked again of `gemini-subscription-flash` with the same prompt (`/tmp/gem/p2.txt`).
