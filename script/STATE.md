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
