# script: where the work stands (read this first when picking it up)

Written 2026-11-12 for a fresh session. Plan and design: `intent.md`. Build: `./build.sh script/impl.S out/script.asm <entries>`
from `trough-lab/pieces` (impl.S only includes the part files). Macros and labels share one namespace across the parts, and
macro names must not be instruction names (STR clashed; it is STRV).

Done and tested (2026-11-12, second session):
- `lex.S` + `tokens.S` (stage 1): `checks/words.py out/script.asm` → 413 scripts, 0 wrong.
- `num.S` (number to text, exact): `checks/numbers.py out/script.asm` → 2637 numbers, 0 wrong.
- `compile.S` (words → instructions, one pass; its head comment says how), `values.S`, `machine.S`, and the entries
  `load`, `run`, `text`, `error` in `entries.S`. Build:
  `./build.sh script/impl.S out/script.asm begin tokens numtext load run text error clock`
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
Getters and setters, and classes, done (seventh unit): **22 of 22 programs, 1257 lines.**
Accessors: a property's value may be a T_ACC value pointing at a pair (getter, setter). `i_getp`/`i_gete` hand such a read to
`m_getter` (an ordinary call whose answer lands in the property's place); `m_setprop` now looks for a setter on the object and
along its prototypes and hands it back, and `m_setter` calls it (call record flag 2: the answer is dropped). Defined by
OP_DEFACC (`c_object`, `c_propkey`, `c_peek_acc`). Soft spot: a literal's or class's plain property with the same name as an
inherited setter is not defined (OP_INITP/INITE go through m_setprop).
Classes: `c_class`, `c_find_ctor`, `c_super` in `compile.S`; OP_EXTENDS, OP_HOME, OP_SUPER in `objects.S`. A class is a
function; a class without a constructor gets a plan with flag 16 that `m_call` passes on to the parent (the function's own
prototype link). `super(...)` calls the parent on the same `this` (the object is made by `new` before, not by the base class);
`super.name` looks from the home object's prototype (F_HOME, set by OP_HOME; functions are 64 bytes now). Not made: fields,
private names, static blocks, refusing a class called without `new`, `super` inside an arrow, a class expression's own name,
getters reached through `super`.
Next: shapes (property lookup by shared layout instead of search), then stage 5 (errors, try/catch/throw, block scope and the
dead zone), each with a Gemini-drafted check program first (it has been right five times).
Help that saves usage: GitHub Actions (`../pieces-repo`, public, pushes with `trough-gh` credentials; `ci/run.sh` now builds
the engine and runs `checks/run.py` there) and the Gemini helper for drafting check programs
(`trough-model-helper ask gemini-auto --prompt-file F`; the reply is JSON, the text is in `.text`; `/tmp/gtools/split.py` shows
how to split it). A random program generator for overnight differential fuzzing was asked of Gemini (`/tmp/gem/out2.txt`); if it is gone, ask again.
CI note: the runner's qjs is older and differs from node on literals.js and numbers.js; `run.py` now counts a program wrong only
when ours differs from node, and prints a note when only qjs differs. The generator request to `gemini-auto` failed once (likely
its 180 second limit); asked again of `gemini-subscription-flash` with the same prompt (`/tmp/gem/p2.txt`).
**Stage 5, first part, done (eighth unit, 2026-11-12 night): `errors.js` passes on its first complete run: 23 of 23 programs, 1286 lines.**
`throw`, `try`/`catch`/`finally` (`s_try`, `s_throw`, `c_try_exits` at the end of `compile.S`; the layout is in the comment
above `s_try`: the finally is written once and reached by OP_GOSUB with two places on the stack). Machine: OP_TRY..OP_RETSUB
(82-87) and `m_throw`, `m_uncaught` in `machine.S`; a try's record is five places on the stack, W_HANDLER the newest. A
return, break or continue that leaves a try ends it and runs its finally (`c_try_exits`, called from `s_return` and
`s_break`). The machine's own errors (`m_fail`, text "Name: message") are thrown as objects of the class of that name when a
try is open. The error classes (Error, TypeError, RangeError, ReferenceError, SyntaxError, EvalError, URIError) are a prelude
written in the language (`c_prelude` in `compile.S`), translated before the program's text on every `load`.
Later the same unit: a pattern in `catch ({a})`, and a global name nothing declared or stored to raises ReferenceError when read (its
place holds T_HOLE; `c_declref` turns that to undefined at translation; `typeof name` reads with OP_GETGQ, 88). `m_raise` (name,
message as string values) is the one way the machine throws its own errors. Gemini's `gerrors.js` passes too: **24 of 24**.
Not made: the catch variable is the function's (no block scope), `Error("m")` without `new`, `stack`,
`cause`, text of an object by its `toString` (so `"" + e` is [object Object]), the dead zone of let and const (comes with block scope: next), messages do not match node's wording, uncaught errors show as
"Uncaught Name: message" in W_ERR without line numbers. `switch` and labelled loops are still missing (stage 2 gaps).
Next: block scope for let/const/class with the dead zone, a fresh loop variable for each turn of a `for (let ..)`, assigning to a
const as TypeError, functions declared in blocks, `switch`, labelled break and continue: Gemini's check program for all of these is
kept at `~/.trough/gem/stage5/scope.js` (8 lines on node; copy it into `checks/programs/` and make it pass). Then shapes.
**Ninth unit: `switch` and labelled break/continue done: `switch.js` passes on its first run, 25 of 25 programs, 1307 lines.**
`s_switch` (layout in its comment; a switch is a loop record with flag 68, so `break` works and `continue` passes it by);
labels: `name:` before a statement is kept in F_LABEL and taken by the next LOOP_IN (record 72, 80); `c_try_exits` now also
takes the loop being left to and drops what each loop on the way keeps on the stack (record 64: 2 for for..in/of, 1 for
switch). c_stmt's frame is 96 bytes. Not made: a label on a plain block.
**Tenth unit: block scope done: Gemini's `scope.js` and my `scope2.js` pass, 27 of 27 programs, 1332 lines.**
How (all in `compile.S`; the comment above `c_block_in` gives the block record): every `{}` statement and every `for` (read
inside a block of its own, `s_forw`) is a block. `c_scan_fn` looks ahead for a function inside it. Without one, a let or const
is one more place among the function's variables (`c_declare_new`: a new name entry with bit 62, bit 63 for const; `c_ref`
searches newest first; `c_block_out` strikes the entries out), or at the top level a nameless global found through a list of
names kept where a function's names would be (`c_alias_new`). With one, the block has a scope object at run time (OP_SCOPE,
OP_UNSCOPE, and OP_COPYSCOPE once per turn of a loop: 89-91) and a record of its own in the R_PARENT chain (flag 256), read by
OP_GETUP 0; functions declared in it are made at its start. `c_declref` decides by F_DECLKIND (set by `c_var`, `s_each`).
Leaving early: `c_try_exits` leaves scopes in step (`c_unscope_to`; loop record 88 and try record 48 hold the block they
began in). Const: `c_ref` notes the read in F_CONSTPOS and `c_lvalue` swaps it for OP_CONSTGET/OP_CONSTERR (92, 93).
`c_realfn` gives the real function past block records (used by return and try).
Not made / soft: the dead zone proper (a let read before its line resolves outward: an undeclared global raises
ReferenceError, an outer variable is silently used); a top-level `const` outside any block can be assigned; class
declarations are var-like; `arguments` or a pattern `var` first met inside a block that has a scope (the second is refused);
a `for (let ..;;)` with no step part does not copy its scope per turn; switch bodies are not blocks of their own; a scope
object per entry of a block with a function is never given back until stage 7.
**Stage 5 is complete apart from those notes.** Next: shapes (property lookup by shared layout), then stage 6, the library
(Object, Array, String, Number, Math, JSON first: this is where page scripts start to run; needs native functions callable
from the language and text of an object by its toString). Ask Gemini for each check program first.
**Stage 6, first unit (2026-11-12, new conversation): the library's base. `library.js` (Gemini's draft) and `library2.js` pass: 29 of 29 programs, 1400 lines.** 54 of 55 lines on the first run.
How: `lib.S` (head comment: the calling shape) holds the built-ins written in machine code, numbered in `n_table`; a built-in
function is a function whose plan has flag 32 and its number at 8 (`m_call` → `m_native`). `prelude.js` (taken in by `.incbin`
at `c_prelude`, translated before every program) names them through `__n(k)`, a global only the opening lines can name
(`c_native_in`/`c_native_out`), and writes the rest of the library in the language: every method that calls a function it is
handed (map, filter, reduce, sort (a stable merge), forEach, ...), and for now also join, slice, concat, indexOf, split, trim,
parseInt, parseFloat, number `toString(radix)` and an exact `toFixed`. `__n(-1..-6, object)` tells the machine what plain
objects, arrays, functions, strings, numbers and booleans inherit from (W_PROTOS; `o_make` sets it by kind, `m_getprop` uses it
for values that are not objects; for..in stops at those objects). In machine code so far (20): Math floor ceil abs sqrt round
trunc sign min max; push pop isArray; Object.keys hasOwnProperty; charCodeAt, one-unit fromCharCode, substring, upper and lower case.
`**` with the power one half is the square root now; other fractional powers still give NaN.
Soft / not made: built-ins cannot call back into the language (why the callback methods are in prelude.js); Math's exp, log,
sin, cos, tan, atan, atan2, random, and general `pow` (next: needs pair arithmetic for a correctly rounded result); JSON; Date;
RegExp; Map, Set, Symbol, Promise; `Function.prototype.call/apply/bind`; text of an object by its own `toString`; `new Array(n)`;
`Object.create/defineProperty/freeze`; hasOwnProperty on an array's items; sort does not move undefined last; case of letters
past 255; `toString(radix)` of a fraction gives up to 52 digits rather than the shortest; prelude methods are slower than
machine code would be (join and indexOf first to move into lib.S). Every load translates prelude.js again (about 9 KB).
**Stage 6, second unit: `math.S`: exp, log, log2, log10, random, and `**`/`Math.pow` with powers that are not whole, in
machine code.** Worked in pairs of doubles (`dd_mul`, `dd_add`, `dd_div`; about 105 bits), rounded once at the end.
`python3 -I checks/curves.py out/script.asm [n] [seed]` compares with exact decimal arithmetic: 11000 random values over four
seeds, 0 wrong, first run (run it with -I: `checks/numbers.py` shadows a standard module otherwise; more than about 600 per
run overflows the world's printed text). Against node the fixed corner cases agree, except `1e308**1.0001` where ours is the
exact answer and node is one unit off. 25 built-ins in machine code now. Next in Math: sin, cos, tan (cut the angle with a
long 2/pi, then the series in pairs), atan, atan2, asin, acos, and expm1, log1p, sinh, cosh, tanh, cbrt, hypot.
**Stage 6, third unit: sin, cos, tan in machine code (`math.S`: `q_sincos`, `q_ser`).** The angle is cut exactly for every
double (1280 bits of 2/pi, `k_2opi`; whole-number multiply, then a pair), then fifteen terms of each series in pairs.
`python3 -I checks/turns.py out/script.asm [n] [seed]` (mpmath, 2000 bits): 8199 values over three seeds, angles up to the
largest double and ones next to multiples of pi/2: 0 wrong, first run. 28 built-ins in machine code. Next in Math: atan,
atan2, asin, acos; expm1, log1p, sinh, cosh, tanh, cbrt, hypot. Then call/apply/bind, object text by toString, JSON.
**Stage 6, fourth unit: `call`, `apply`, `bind`, and an object's text by its own `toString`. `calls.js` passes: 30 of 30
programs, 1412 lines** (second run; the first found that top-level functions are made before the library registers what
functions inherit from: `__n(-3, ..)` now goes through the globals and gives them it). How: built-ins 28 and 29 are not
routines but turns of the call (`m_fcall`, `m_fapply` in lib.S: rearrange the stack, go on into `m_call`); `bind` is in
prelude.js. `i_add` meeting an object goes to `m_toprim`: a plain object's `toString`, if a function, is called with the
answer to land in the object's place (call kinds 3 and 4, finished by `m_answer`) and the instruction runs again. Only `+`
(so also `+=`, templates, `String(x)`, join) does this so far: not `==`, comparison, arithmetic (`valueOf`), property keys,
or `console.log` of an object. A function nested in a block that ran before registration is not an issue (they are made later).
Recorded, not made: outside strict mode the language wraps a number, string or boolean given as `this` in an object
(`typeof this` is "object") and makes a missing `this` the global object; ours passes the value as it is, as strict mode does.
The line in calls.js that showed it was changed to `this+1`.
**Stage 6, fifth unit: JSON. `json.js` passes: 31 of 31 programs, 1455 lines** (second run). `JSON.parse` is machine code
(`json.S`, built-in 30: reads the text where it lies, x23/x24 the place and end; strings are read twice, count then fill;
whole numbers to fifteen digits directly, others through `v_text_number`; nesting to what 128 KB of stack allows;
SyntaxError otherwise). `JSON.stringify` (indent, replacer function, toJSON) and the reviver are in prelude.js. The first run
found a real fault outside JSON: `a["0"]` on an array did not reach item 0; `m_index` now takes text that is a whole number
as printed (to nine digits). Not made: a replacer given as a list of names; escaping lone halves of a pair in stringify.
31 built-in numbers in `n_table` (29 routines in machine code, 2 are call and apply).
**Stage 6, sixth unit (2026-11-12 night, new conversation): the rest of Math in machine code: atan, atan2, asin, acos, expm1,
log1p, sinh, cosh, tanh, cbrt, hypot (built-ins 31 to 41; `math.S`).** `python3 -I checks/arcs.py out/script.asm [n] [seed]`
(mpmath, 2000 bits): 25944 values over three seeds, 0 wrong, first run; 136 fixed corner cases (signed noughts, the endless,
all 49 atan2 pairs) agree with node. How: `q_atan2` (the smaller over the larger, a table of nine angles `k_atan`, a series
to u^30) carries all four arc functions (asin and acos hand it x and the root of (1 - x)(1 + x), `dd_sqrt`); `q_expp` is
`q_exp` before its scaling (a pair and a power of two; `q_scale` rounds once) and carries expm1, sinh, cosh, tanh, cbrt
(e to a third of `q_log`); small expm1 has its own series, small sinh and tanh use `q_ser` with the square's sign turned;
hypot squares exactly as pairs after scaling by 2^600 either way. 40 routines in machine code. Not made: asinh, acosh, atanh,
fround, clz32, imul; a hypot that lies exactly half way between two doubles (possible, not met) may round either way.
Next: Map, Set, Symbol.iterator enough for for..of over them.
**Stage 6, seventh unit: Map, Set, and going through anything iterable. `collections.js` and `math2.js` (Gemini's draft)
pass: 33 of 33 programs.** How: an instruction that wants an array to go through (OP_ITER, spread, the rest of a list) and
meets something else calls the prelude's function registered by `__n(-8, f)` (W_ITERFN; `m_drain` in lib.S, call kind 5:
the answer takes the value's place and the instruction runs again). That function calls the value's `'@@iterator'` method
(`Symbol.iterator` is that string: `Symbol` is a plain object, not a new kind of value) and drains `next()` into an array.
A list pattern `[a, b] = v` now begins with OP_ITER. Map and Set are in prelude.js: a plain object as the index (keys 's' +
text, 'n' + number, 'o' + built-in 42 `n_ident`, the object's place in the world, 'x' + the rest), arrays of keys and
values in order, holes packed away after deletions. Arrays have values, keys, entries and `[Symbol.iterator]`.
Soft / not made: an iterator is drained whole before the loop begins (an endless one never ends; changes made to a Map
during its loop are not seen); real symbols; WeakMap, WeakSet; a Map's `_h`, `_k`, `_v`, `_d` and its methods show in
for..in (no hidden properties yet); `[a, b] = v` as an expression gives the array made from v, not v; text of a function.
`Math.expm1(1)`, `Math.log1p(2)`, `Math.hypot(1e-300,1e-300)`: node and qjs are one unit off, ours is the exact rounding (mpmath);
math2.js therefore prints numbers cut to 14 digits (its `R`), and minus nought in a label is written neg0 (run.py rewrites node's -0).
Next: asinh, acosh, atanh, fround, clz32, imul; then join, indexOf, slice into lib.S; shapes; RegExp.
**Stage 6, eighth unit: asinh, acosh, atanh, fround, clz32, imul in machine code (built-ins 43 to 48; 42 is `n_ident`).
Math is complete.** `q_log1pp` (the logarithm of 1 + a pair) carries log1p and the three inverse hyperbolic ones.
`checks/arcs.py` 150 3: 8858 values, 0 wrong, first run that built; `Math.asinh(1e300)` and `acosh(1e300)`: node is a unit
off, ours exact. 46 routines in machine code. Trap met: `n_nan` is num.S's text "NaN", not a routine (mine is `n_notnum`).
Next: join, indexOf, slice into lib.S; shapes; RegExp.
**Stage 6, ninth unit: array join, indexOf, slice in machine code (built-ins 49 to 51). `arrays3.js` passes: 34 of 34.**
`m_native` sends 49-51 to the prelude's own version (W_FALLBACK, registered by `__n(-9..-11, f)`; a turn of the call like
`call`) when `this` is not an array, and join also when an item is an object (its toString may be the program's). `n_join`
is two passes (texts and sizes, then one string filled). Measured: 30 joins of 300 numbers with indexOf and slice take
about 20 ms; the prelude's join filled the 1.2 MB test world after about five (a new string per item, nothing given back
before stage 7), so no time comparison was had. Found, not made: empty places in a list `[, 'a', ,]` are a SyntaxError;
a full world ends the run with no error text. 49 routines in machine code.
Next: shapes; string indexOf, slice, split, trim, concat and array includes, lastIndexOf, concat into lib.S; RegExp.
**Small repairs after the ninth unit:** empty places in a list (`[, 'a', ,]`) are taken (kept as undefined, not as true
holes); a full world now stops with "RangeError: the world is full" (its text is made at the start, W_K_FULL). 34 of 34.
**Order changed (my judgement, said to the user):** RegExp comes before shapes. Shapes only make lookups faster; page
scripts cannot run at all without RegExp, Date, Promise and timers. Next: RegExp (read intent.md's stage list first; ask
Gemini for the check program with tight instructions: no "-0" in labels, no exact digits of curved functions).
**Stage 6, tenth unit: regular expressions, first half: `regex.S` (new, about 1000 lines): the translator and the matcher
in machine code; built-ins 52 (pattern, flags -> program) and 53 (program, text, from, sticky -> the groups' places or
null). `RegExp` with exec, test, lastIndex, toString in prelude.js.** `python3 -I checks/patterns.py out/script.asm
[cases.json]` against node: 77 of 77 (66 of 68 on the first run; the two were captures forgetting at each turn of a
repeat, RX_CLEAR, and `\N` past the pattern's groups being an old octal code). 34 of 34 programs still.
How: the file's head lists the 21 instructions. A backtracking matcher; its places to come back to live in one block
of the world (W_RXSTACK, doubled when full, reused); a limit of 64M steps. Repeats by count copy the thing; a repeat
with no end of something that could match nothing has RX_MARK / RX_CHKADV. Looking ahead runs the matcher inside itself.
Not made: pattern literals `/x/g` in the translator (next); String match, matchAll, replace, split, search with a RegExp
(next, in prelude.js); looking behind (refused with a SyntaxError); named groups (taken, names not kept; `\k<n>` not);
the u and v flags, `\p{..}`, pairs of units as one character; ignoring case past western European letters;
`[^]`/`[]` agree with node. A Gemini list of 150 patterns was asked for into /tmp/gout2.json (not back when this was
written: `patterns.py out/script.asm FILE` runs any such list). 51 routines in machine code.
**Stage 6, eleventh unit: pattern literals and the text functions that take patterns. 35 of 35 programs (`regexp2.js`, 27 lines,
agreed on the first complete run).** `c_rxlit` (compile.S): `/source/flags` is written as the call `RegExp("source", "flags")`
through the global RegExp (a program that replaces that global changes its literals: soft). The reader already cut patterns out
(kind 7); one repair there: after `++` and `--` the slash's meaning stays as it was (`a++ / 2` divides). In prelude.js, inside
RegExp's closure: match, matchAll (an array's values, made whole first), search, replace and replaceAll (text or pattern;
`$$ $& $` $' $1..$99`, or a function), split by a pattern (captures spliced in, a limit). Not made: `$<name>`; Symbol.replace
and its kin; a literal directly after `}` or `)` is read by the reader's simple rule. Gemini's first list never came (its reply
was an error); asked again for a 120-line usage program into /tmp/gout3.json (strip any fences, run with run.py, keep it as
`regexp3.js` if the references agree with each other).
Next: Date; Promise and timers (need the host); shapes; the overnight differential fuzz job.
**Stage 6, twelfth unit: Date, and objects as numbers. 36 of 36 programs (`dates.js`, 19 lines; 14 right on the first run).**
`date.S` (new): built-ins 54 now(0 clock, 1 minutes ahead), 55 (year, month) -> days from 1970, 56 days -> (year*12+month)*32+day,
by the 400-year turn. New entry `clock` (argument: low 48 bits the milliseconds, top 16 the minutes local time is ahead; kept in
W_CLOCK 480, W_TZ 488): the build line now ends `... error clock`; seen right with a fixed time and +120 minutes. The Date object
is in prelude.js (its time in `_t`): constructor, UTC, parse (the ISO form by our own patterns; "Feb 29, 2024 10:20:30",
"29 February 2024", toString's and toUTCString's forms, m/d/yyyy), all getters and setters, toISOString, toJSON, toString and kin,
en-US toLocale*. `m_tonum` (lib.S, beside m_toprim): arithmetic (`TWO`'s slow path), comparison, unary + and - meeting a plain
object call its valueOf, else its toString, and run again; `+` tries '@@toPrimitive' (a Date's: its text), then valueOf, then
toString. 54 routines in machine code.
Not made: built-ins given an object where a number is wanted (`Math.max(date1, date2)` is NaN: they cannot call back); `==`
with an object; a valueOf that answers an object runs until the steps end; daylight saving (one fixed offset for the whole
run); zone names other than GMT+hhmm; toLocale* for other places or options; the host does not call `clock` yet (0 until it does).
Next: Promise and timers (need the host: a queue of jobs the host drives; setTimeout through the clock); then hook the engine
into the page piece's <script> elements; shapes; the fuzz job.
**Stage 6, thirteenth unit: Promise, the job queue, timers. 37 of 37 programs (`promises.js`, 37 lines).**
In prelude.js (its last part): the queue `__q` (a global that outlives loads: jobs `m`, timers `t`), Promise (then, catch, finally,
resolve, reject, all, allSettled, race, any; adoption of thenables takes the standard's two turns), queueMicrotask, setTimeout,
setInterval, clearTimeout, clearInterval, and `__jobs`. Machine code: every program now ends `__jobs()` before OP_HALT
(compile.S, at the program's end; where that ending begins is W_JOBS_PC 520); built-ins 57 (move the clock) and 58 (say when to
wake); `now(2)`: has the host given a clock. Two ways of time: no host clock (the bench): `__jobs` runs every timer in order of
its time, moving the clock to each (virtual time: exact, instant); host clock given: only what is due runs, and
`clock 0` answers when the next is due (-1: none); `clock T` then sets a finished program back at its ending, so the next
`run` runs the due timers without loading anything (seen: set, not fired at +20 ms, fired at +60, then -1).
The world's header is now 576 bytes (was 512: 336 to 383 is W_PROTOS's six values, NOT free; I wrote two fields there
first and the bench crashed). A piece has room for eight entries (loader/piece.h), so `wake` is `clock 0`.
run.py compares timer programs with node only (this qjs has no setTimeout); node's real timers jitter, so keep a test's
due times 8 ms or more apart. 56 routines in machine code.
Found, not made: a try/catch inside a block that holds a function (the catch variable is the function's; refused as "not made
yet": prelude's `gt` works around it); unhandled rejections are silent; async functions and await (next: a translation onto
promises, needs a function that can stop and go on: the machine's frames kept aside); each `load` still starts the
instructions afresh, so functions of an earlier load cannot be called (several scripts in one page need appending).
Next: async/await and generators (one mechanism: a kept frame); appending loads; running a page's <script> elements from
host/browse.c (clock, run, `clock 0` for the wake time); shapes; the fuzz job.
**Stage 6, fourteenth unit: generators and async functions, one mechanism (a kept call). 39 of 39 programs (`generators.js` 13
lines, `async.js` 17 lines; each right on its first complete run).**
Machine code (machine.S, its comment "Kept calls" says the layout): OP_GENSNAP 94, OP_YIELD 95, `m_snap`, and built-in 59
`m_resume` (a turn of the call, like call and apply). A call that stops is copied off the stack into an array (variables, record,
what its instructions had on the stack, seven plain numbers) and copied back above the resuming call; its open try records are
moved and joined to the chain again. W_GENFN 528 (two values, set by `__n(-12, f)` and `__n(-13, f)`): what makes a generator
of a holder, what drives an async function. Translator: `function*`, `yield`, `yield*` (the loopable's items in turn), methods
`*name(){}` and `async name(){}` in objects and classes, `async function`, async arrows, `await` (the same instruction as yield).
A function's kind waits in F_PEND (the translator's frame is 176 bytes now) and lives in its flags: 64 generator, 128 async.
prelude.js (its last part): next, return (a private marker is thrown in so finally blocks run), throw; the async driver on promises.
Not made: looping over a generator (`for..of`, spread) still collects everything first, so an endless generator in a loop with
`break` never ends (the loop instructions want an array; a lazy path is needed); `yield*` drops what is sent in and the inner
generator's final answer; async generators and `for await`; `await` at the top of a script; a catch-all in a generator also
catches the marker of `return()`; a generator's own `prototype`; the hidden fields `_h _r _s _d` show in `for..in`.
Next: appending loads (several scripts, one world); a page's <script> elements from host/browse.c; lazy loops; shapes; the fuzz job.
**Fifteenth unit: loads append.** A `load` into a world whose program has ended (state 2) or stopped on an error (3) adds its
instructions after the old ones (compile.S, c_compile: frame 168 is where this script begins; the prelude is translated the
first time only). Globals, constants, functions, classes, the job queue and timers carry over; a script that throws or does not
translate leaves the world usable for the next. Seen: `checks/append/t.py` (five scripts, one world; its expected output is the
six lines it prints: one 3 / timer / two 6 2,3 page 8 / three later 6 function 7,9,12 / async in three 12 / five 12 later 12).
Not made: instructions are never given back, so a page that loads thousands of scripts fills the code room; a top-level
`let` named again by a later script is not refused.
Next: a page's <script> elements from host/browse.c with a small document object; lazy loops over generators; shapes; fuzz job.
**Sixteenth unit: the program can ask its host.** `__host(text)` (a global; prelude.js last line; built-ins 60 and 61 in lib.S):
the request joins the printed output, W_WANT 544 says where it begins (plus one), and `run` answers 1 at once. The host calls
`text`: its answer's top 32 bits are W_WANT (0: no request), the low 32 the bytes copied; it answers with `text` given a second
number 1 and its block holding the answer (UTF-8; kept in W_ANSWER 552), then calls `run` again; `__host` returns the answer
(undefined if none). No new entry was needed (the eight are used). Seen: `checks/host/t.py` (copy of the bench run; it uses
/tmp/h paths) prints "host said Grüße from the host Grüße from the host". 61 routines in machine code.
Next: host/browse.c finds a page's <script> elements, loads each into one world (a small `document` written in the language
over `__host`: write, title), splices document.write's text into the page before `page render`; then a `dom` piece.
**Seventeenth unit: the browser host runs a page's scripts (host/browse.c, `with_scripts`; C, as the host is).** Before
`page render`, every <script> element (inline, or fetched by src; type absent or ...javascript) is loaded in page order into one
32 MB world of `script.asm`; `document` (write, writeln, title), `location.href`, `navigator.userAgent`, `window` are a few
lines of the language over `__host` (`page_opening` in browse.c); what a script writes takes its element's place in the page's
text. Console output and errors go to the host's stderr; the result line says how many scripts ran and failed. Both the
one-picture path and the live screen (`--serve`) call it. Seen: `checks/page/index.html` + `lib.js` (served from a throwaway
bench server on 127.0.0.1): the picture shows the script-written paragraph, a three-item list from a generator in the fetched
file, and the sum line with the changed title; a JSON block skipped; a throwing script did not stop the next; `async gave 42`.
Real sites (news.ycombinator.com, www.wikipedia.org, example.com): no crash, pages draw as before, their scripts fail for want
of a tree ("not a function": getElementById and kin); one SyntaxError in Wikipedia's inline script at column 5690 (not looked
at); example.com reported one failed script, not looked at. Not made: timers after the page is drawn (the host gives the clock
but never calls `clock 0`), modules, defer/async order, document.write of a further <script>, events, any tree.
Next: the `dom` piece (the page as a tree, in machine code) and getElementById, textContent, innerHTML, createElement,
appendChild over `__host`; find Wikipedia's SyntaxError; lazy loops over generators; shapes; the fuzz job.
**Fault found on a real page (2026-11-13): a pattern straight after `return`.** `return/Android/i.test(s)` (Wikipedia's
minified script) was refused: the reader's rule "a slash after this or super divides" named keywords 21 and 23 (return,
switch) instead of 22 and 24. Both lex.S and the separate statement in checks/words.py carried the same two numbers, so they
agreed with each other; words.py now names the words. Added `programs/slash.js`. With a stand-in document, the scripts of
www.wikipedia.org (27 kB minified), example.com and news.ycombinator.com now translate whole and run until they want the
tree (`Element is not defined`, a property of a missing element, a missing document function).

**Eighteenth unit: the page is a tree (the `dom` piece, 2026-11-13; hand-written, 6272 bytes; `dom/intent.md`).** One block holds the
tree; `ask` answers short written requests (find an id, a tag or class under a node, read or set text, attributes, inner HTML, make,
put, take out, document.write before the running script). `dom/document.js` (in the language; the host loads `out/document.js` as
the page's first script) gives `document`, `Element` and its kin, events (`addEventListener`, `dispatchEvent`; the host runs
`__fire()` after the last script: DOMContentLoaded, load), compound selectors, classList, `window`, `location`, `navigator` and
small stand-ins (storage, matchMedia, history). host/browse.c `with_scripts` now reads the page into the tree, finds the script
elements by asking it (`q1 script`), passes `__host('d...')` straight through (`tree_ask`), and draws the tree written back out
(`h1`); a refused request comes back as "\x01E" and `__d` throws. Seen: `dom/checks/t.txt` -> `t.out` (62 requests, read by hand);
`dom/checks/page/index.html` -> out/dom-page.png shown on Home (heading rewritten, items made and put first, counts by selector,
write in place, a line added on DOMContentLoaded, a child under itself refused); script/checks/page still draws. Real sites:
example.com 1 of 1 and news.ycombinator.com 1 of 1 scripts run clean; www.wikipedia.org 3 of 4 (the fourth:
`eventLoggingLite is not defined`, a name another script put on `window`).
Engine gaps met here, in the order worth doing: (1) `window`/`globalThis` must BE the global scope (a property set on it is a
global and the reverse); (2) `console` is not a value (`window.console=console` is a SyntaxError; `typeof console`); (3)
`Object.defineProperty` and its kin are missing; (4) `Symbol` is not a function, no WeakMap, no Proxy. Not made in the tree:
giving room back, attribute name lists (so `dataset`, `attributes`, cloneNode without innerHTML), implied html/head/body and the
other implied endings, pseudo-classes (matched as true), `~` and exact `>` `+` combinators (read as "somewhere inside"),
scripts added by scripts, timers after the page is drawn, style and layout answers (all 0). page still lays out from text; walking
the records directly (and redrawing after an event) is the step that makes pages live.
Next: (1) and (2) above in the engine; then timers and a click reaching `dispatchEvent` from the live screen, redrawing from the
tree; lazy loops; shapes; the fuzz job.

**Nineteenth unit: the global object, and console as a value (2026-11-13).** `globalThis` (prelude; built-in 62, lib.S n_global,
W_GOBJ 560) is an object whose properties ARE the global variables: objects.S o_find answers from the globals table (a name
nothing has stored to is not there) and o_put stores into the global of that name, filling one that was only named before or
adding a new one. So `window.x = 1` in one script is `x` in the next, and a function that named `x` earlier now finds it.
`console` is an object of the prelude (log, info, warn, error, debug and quiet stand-ins); the translator's own print form is now
spelled `__console.log(` and the prelude's functions call it. dom/document.js: `window`, `self`, `top`, `parent` are globalThis;
window's listeners live on a hidden target behind the global addEventListener. 63 routines in machine code; 41 of 41 programs
(`programs/global.js`). Real pages, scripts run / failed: www.wikipedia.org 4/0, an en.wikipedia.org article (1.4 MB) 4/0,
news.ycombinator.com 1/0, lite.cnn.com 2/0, example.com 1/0.
Not made: `this` at the top of a script is undefined (should be globalThis); `Object.keys(globalThis)` is empty and `delete` on
it does nothing; Object.defineProperty and kin; Symbol as a function, WeakMap, Proxy; scripts that scripts add (Wikipedia's
loader adds its real code that way, so "no failures" is not yet "the page's code all ran").
Next: scripts added by scripts (an appended script element with src or text runs), top-level `this`, Object.defineProperty; then
timers after load and a click from the live screen reaching dispatchEvent with a redraw from the tree; lazy loops; shapes; fuzz.

**Twentieth unit: Object's own functions, `this`, scripts that add scripts (2026-11-13).** Built-ins 63 to 65 (lib.S: n_defacc
stores a getter and setter pair; n_getproto, n_setproto): 66 routines in machine code. On them, in prelude.js: Object.defineProperty,
defineProperties, create, getPrototypeOf, setPrototypeOf, getOwnPropertyNames, getOwnPropertyDescriptor (always a plain value),
is, fromEntries; freeze, seal, preventExtensions are accepted and do nothing. `this` at the top of a script, and in a function
called plainly, is globalThis (objects.S m_this: an undefined `this` reads as the global object, so strict code sees it too).
Also in prelude.js: encodeURIComponent, encodeURI, decodeURIComponent, decodeURI, String.fromCodePoint, codePointAt.
host/browse.c: after each round of scripts the tree is asked for its script elements again and any not yet run is run (40 rounds,
400 scripts at most); a fetched script gets `__loaded(node, ok)` (load or error event; an HTML answer counts as a failure); when
a round finds nothing new, `__fire()` runs once, then rounds go on until quiet. 43 of 43 programs (`objectfns.js`, `uri.js`).
Seen: dom/checks/page/added.html -> out/added-page.png (a fetched added script, its onload, a missing one's onerror, an added
inline script with this === window, a window property made by defineProperty, the load listener).
Real pages now: www.wikipedia.org 4/0, news.ycombinator.com 1/0, lite.cnn.com 2/0; old.reddit.com 15 run, 6 failed (two
SyntaxErrors in its big scripts, at line 2 columns 86 and 1605, not looked at; `SML is not defined` follows from them).
Not made: properties that do not show in loops (defineProperty's are all enumerable), real freezing, `__proto__`, accessors
defined on globalThis, escape/unescape, URL and URLSearchParams, XMLHttpRequest and fetch, Symbol as a function, WeakMap, Proxy.
Next: the two SyntaxErrors on old.reddit.com (fetch the script, cut around the column); then timers after load and a tap on the
live screen reaching dispatchEvent with a redraw from the tree; XMLHttpRequest/fetch through the host; lazy loops; shapes; fuzz.
The map (MAP.md) has NOT been regenerated since unit 17: line numbers in objects.S, lib.S are off by the lines added here.

**Twenty-first unit: constructs real sites stopped on (2026-11-13).** Found by keeping each script that fails to translate
(`TROUGH_KEEP_FAILED=<dir> out/browse ...` writes failed-N.js there) and cutting around the reported column. Made, all in
compile.S: (1) optional chaining `a?.b`, `a?.[k]`, `a?.(x)`, `o.m?.(x)` (c_postfix: after `?.` c_guard writes JNK over
"UNDEF; JMP end-of-chain"; six `?.` at most in one chain) - it was not in the engine at all; (2) a `catch (e)` inside a block
whose let/const an inner function uses (the advance scan c_scan_block now declares catch names in the function); (3) static,
async, await, of, get, set as names of functions and parameters, and alone in an object (`{get, set}`); (4) object spread
`{...a, b: 1}` (a call of the prelude's `__spread`, which is Object.assign). 44 of 44 programs (`optional.js` holds all four).
Real pages now, scripts run / failed: www.wikipedia.org 4/0, news.ycombinator.com and lite.cnn.com clean, github.com 0 failed,
the en.wikipedia.org article 6 run (see the last line of the session for its count), old.reddit.com 15/6, www.bbc.com/news 42
failed. Known next stops: old.reddit.com `await` after a comma inside what should be an async function
(`n.isEvaluating=!0,await Promise.resolve();let t=await Promise.all` at line 2 column 4523 of its loader: find which kind of
function that is) and dynamic `import(x)`; bbc.com: six "Unexpected token" kinds, not looked at (run with TROUGH_KEEP_FAILED).
Next: those stops, in the order that unblocks most scripts; regenerate MAP.md; then timers after load, a tap reaching
dispatchEvent with a redraw from the tree; XMLHttpRequest/fetch through the host.

**Twenty-second unit: what BBC News and Reddit stopped on (2026-11-13).** All in compile.S unless said; 45 of 45 programs
(`site2.js` holds every case below). (1) Tagged templates (c_tagged, from c_postfix): the call is OP_APPLY on one array, the
pieces' array first (no `raw` yet). (2) `??=`, `||=`, `&&=` on a property. (3) The rest of an object in a pattern
(`{a, ...r}`): c_pattern keeps up to 32 plain keys and calls the prelude's `__rest(value, keys...)`; a worked-out or numeric
key before a rest is still "not made". (4) Class fields: c_fields goes through the class body and writes `this[key] = value`
INTO THE CONSTRUCTOR (at its start, or right after `super(...)`; F_FPEND/F_FCUR carry the body's place; with no constructor
the text `(){}` or `(...a){super(...a)}` is read from the piece itself); static fields are set in c_class; static blocks are
c_function kind 5 called on the class; the class's name holds it before its members are read. Known: initialisers see the
constructor's parameters; `super()` inside an arrow sets no fields; private names (#x) not made. (5) A named statement that
is not a loop (`e:{... break e}`): a loop record with 68 = 2 that plain break and continue pass by. (6) await and yield inside
a block with its own scope were refused (c_inkept looked at the block's record): fixed. (7) `arguments` read inside such a
block, or inside an arrow, was empty: the advance scan (c_scan_block) now declares it in the function; an arrow's record has
bit 9 and never makes its own. (8) lex.S: a template inside a template's `${ }` is now read as a template (depths wait on the
stack); before, braces and quotes in the inner text lost the reader's place (every styled-components file). (9) `import(x)`
and `import.meta` are the prelude's `__import` (answers with a refusal for now). prelude.js: WeakMap, WeakSet (Map and Set
themselves), WeakRef, FinalizationRegistry. dom/document.js: performance, Image, customElements (copy it to out/ after edits).
Real pages, scripts run / failed: old.reddit.com 17/0 (was 15/6), www.bbc.com/news 57/6 (was 17/42), www.wikipedia.org 4/0.
What stops now: BBC `for await (x of y)` and `async function*` (not made), two "not a function" at run time (not looked at),
reddit and others `fetch is not defined` in a load listener. checks/runbig.py is run.py with a 32 MB world (big scripts).
Next: fetch and XMLHttpRequest through the host (most asked for by pages now); timers after load and a tap reaching
dispatchEvent with a redraw from the tree; async generators and for await; real modules behind `__import`; shapes; fuzz.

**Twenty-third unit: pages fetch, and timers run after load (2026-11-13).** host/browse.c: a script's `__host('f' + address)`
is answered with "1", three digits of status and the body (or "0" and why): resolved against the page, fetched by fetch_body
(GET only, 16 a page, headers of the answer not kept). After `__fire()` the rounds go on (400 at most): when nothing new is
to run, `clock 0` gives the next timer's time; if it is within three seconds of the page's start the clock is MOVED to it
and the world run again (run_script with no text), 300 times at most: virtual time, no waiting. dom/document.js (in the
language): Headers, Request, Response (text, json, clone), fetch (a promise, settled one timer later), XMLHttpRequest (open,
send, onload/onerror/onreadystatechange/loadend, addEventListener, responseType json). Seen: dom/checks/page/fetch.html served
from the bench (a python http.server on 8765 in that folder) -> out/fetch-page.png: fetch ok, xhr 200 state 4, a missing
file 404, JSON read through await. old.reddit.com 17/0 and it fetched its preload address; bbc 57/6 as before.
Not made: POST and other methods, request headers and cookies, response headers, binary bodies (arrayBuffer, blob), abort
signals, real waiting (a timer more than 3 s out never runs in the one-shot host).
Next: the live screen (PieceScreen) keeping the world alive: a tap reaching dispatchEvent, timers by the real clock, a redraw
from the tree; bbc's run-time "not a function" (find with a small trace of the callee's name); async generators and
for await; POST; modules behind `__import`; shapes; fuzz.

**Twenty-fourth unit (Fable, finished and pushed by Opus): positions for run-time errors, and faults real pages found
(2026-11-13).** OP_LINE (96; 8 bytes: line, column) is written by c_pos at the start of every statement of the program's own
text; i_line keeps it in W_POS (568); m_fail and i_throw copy it to W_ERR_LINE, so `error` reports where a run-time error
happened (the statement last begun: after a call returns it is the callee's last statement). host/browse.c keeps a script that
fails while running too (TROUGH_KEEP_FAILED). prelude.js: Array(n) and Array(a, b) as plain calls (were undefined), Object(v),
Symbol as a function (a unique '@@desc@n' string; Symbol.for, keyFor, the well-known names), propertyIsEnumerable,
isPrototypeOf, getOwnPropertySymbols. objects.S m_delprop: a property found on a prototype or outside the own list was
"deleted" by moving memory past the list's end: the browser host crashed on bbc.com; now left alone. 45 of 45.
bbc.com/news after this: 57 run, 17 failed: 12 of them one stop in the turbopack loader (failed-3 col 9045 area).

**Twenty-fifth unit [by Opus]: named property errors, Error without new, async function hoisting (2026-11-13).**
(1) objects.S m_nokey: reading or setting a property of undefined/null throws "Cannot read properties of undefined (reading
'name')" / "Cannot set properties of null (setting 'name')" as browsers do (text built on the stack, stack given back before
m_raise; keys over 80 bytes or wide are left out); i_in still uses the plain m_noprops. (2) compile.S c_prelude: the error
classes are functions now (`__errclass`), so `Error("x")`, `TypeError("y")` without new make errors (a class called plainly ran
on the global object and gave undefined: every minified `throw Error(...)` threw undefined); `{cause}` kept;
Error.captureStackTrace is a no-op. (3) compile.S c_scan_block: `async function name` at a statement's start is a declaration
(it was declared only when reached, so it was undefined before its line, and the late declaration put a name into a slot the
scan had already given out: the bbc turbopack loader's `e` read another variable). 45 of 45 (site2.js has all three).
bbc.com/news: 57 run, 4 failed (was 17): two "not a function" (col 2497/2503 of one script), piano SDK's own error, `for await`.
Known, not fixed: Object.keys(new Error("k")) lists "message" (defineProperty cannot make a property non-enumerable yet).
No garbage collector: about 20000 caught errors fill a 1.2 MB bench world (each makes strings and an object). A name declared
during translation that the scan did not see can still share a slot: only the async case is closed.
