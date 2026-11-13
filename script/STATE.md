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

**Twenty-sixth unit [by Opus]: catch gets its own scope; errors keep the place they were made (2026-11-13).**
(1) compile.S s_try: `catch (name) { ... }` is a block of its own (c_scan_fn + c_block_in, the name declared as a let with
F_DECLKIND 1, the body's statements read in place, c_block_out before OP_ENDTRY); c_scan_block no longer declares catch names in
the function (the jump at its old place skips that code). Before, the catch name was a variable of the whole function, so in
`function(){try{return e()}catch(e){...}}` the try's `e` read the catch's (undefined): esbuild's __commonJS helper
(`c=function(e,n){return function(){try{return n||e(...)}catch(e){throw n=0,e}}}`) failed for every lazy module. A catch with a
pattern ({a}) still declares in the function. (2) lib.S built-in 66 n_markerr: W_POS becomes W_ERR_LINE and comes back as
line * 2^32 + column; the Error function calls it and sets `stack` ("Name: message\n    at <anonymous>:L:C"). machine.S
i_throw: throwing an object no longer overwrites the place, so a rethrow reports where the error was made.
(3) host/browse.c: TROUGH_KEEP_ALL=<dir> saves every script run as ran-N.js (an error in a timer or listener is reported
while a later script runs, and its place is in the earlier script's text: search all of them for the column).
45 of 45 (site2.js +9 catch cases). bbc.com/news 57 run, 4 failed: piano SDK's own two errors (its logic), `for await`
(SyntaxError), one "not a function" (line 1 col 2497 of SOME script; best guess ran-7.js, core-js, a statement `return t` in
its aCallable check J, after which the caller calls t: something whose typeof is "function" cannot be called. Not confirmed.)
Known: OP_LINE positions are not tied to a script, so callbacks report into the wrong file; tagging W_POS with a script
number needs a world field (the header is full at 576: W_POS took 568).

**Twenty-seventh unit [by Opus]: what was called, and the BBC's last run-time stop found (2026-11-13).** machine.S m_call: calling
a non-function now says what it was ("TypeError: undefined is not a function", null, a number, a string, a boolean, an object):
m_notfn_v / m_notfn_o. host/browse.c: with TROUGH_KEEP_ALL each run-time error is followed by " [ran-N]", the script running
when it happened (s->which). 45 of 45.
FOUND (not fixed): bbc ran-55 is `self.__SSG_MANIFEST=new Set([])`; it fails because core-js (ran-7) has REPLACED Set, Map and
Symbol: our Symbol() gives a string, so core-js's check (`Object(Symbol()) instanceof Symbol`, typeof "symbol") fails and it
installs its own Symbol. Its Symbol.iterator is then a key no array has (`[1][Symbol.iterator]` is undefined after core-js
loads), so anything iterated by library code fails. Reproduce: /tmp-style bench file = small stand-ins for window/document +
ran-7.js + `[1][Symbol.iterator]()`. FIX: a real symbol type (a tag of its own, typeof "symbol", unique, usable as a property
key, never equal to a string, Object(sym) instanceof Symbol, description, toString "Symbol(desc)", well-known symbols that the
engine's own for..of / spread / toPrimitive use instead of the '@@iterator' strings). Next unit.

**Twenty-eighth unit [by Opus]: symbols that libraries accept; Object.prototype.toString; Array.from (2026-11-13).**
(1) A symbol is a string whose first unit is 1: `\x01 description \x01 n` from Symbol(d), `\x01Symbol.name` for the well-known
ones (iterator, asyncIterator, toPrimitive, toStringTag, ...). machine.S i_typeof: such a narrow string is "symbol".
prelude.js: every '@@iterator'/'@@asyncIterator'/'@@toPrimitive' is now '\x01Symbol.…' (objects.S k_toprim too); String(sym)
is "Symbol(desc)"; Object(sym) is a wrapper with Symbol.prototype (description, toString); `new Symbol` throws. core-js now
keeps our Symbol. Known: Object.keys and for..in list symbol keys (with the marker); `'\x01...'+''` is not refused; Object(3) is
still 3 (no number/string wrappers). (2) compile.S c_object: `[key](){}` (and *[key], async [key]) methods. (3) prelude:
Array.from (iterables, array-likes, map function) and Array.of: they did not exist. (4) Object.prototype.toString answers
[object Function/Array/Number/String/Boolean/Symbol/Date/RegExp/Error/...] and honours Symbol.toStringTag (set on Math, JSON,
Map, Set, Promise, Symbol): core-js decides whether bind is native by it (it said "Object" for functions, so core-js's bind
helper was undefined and every Set/Map built from a list failed). (5) checks/run.py warns when node itself stops on a program:
site2.js had two name clashes (k, m) that stopped node halfway, so half of it was not compared; fixed (1905 lines now).
bbc.com/news: 57 run, 3 failed: piano SDK's own two (logic), `for await` (SyntaxError). old.reddit 17/0 to be rechecked.

**Twenty-ninth unit [by Opus]: async generators (2026-11-13).** `async function*`, `async *m(){}` in objects and classes.
compile.S: c_function keeps the async flag when `*` follows (flags 192); c_methkind takes `async *name` (F_PEND 192) and
`async *` after async; c_kept writes OP_GENSNAP 2 for flags 192; `await v` inside an async generator is `yield __awrap(v)`
(c_w_awrap). machine.S i_gensnap: kind 2 calls the driver in W_GENFN3. world.S: the header is 592 bytes (W_GENFN3 576; 584 free;
w_begin clears 66 words). lib.S: `__n(-14, f)` registers it. prelude.js (in the generator block): AG objects (next, return,
throw give promises; requests wait their turn; a yield's value is awaited; return runs finally blocks through RT;
Symbol.asyncIterator gives itself). 46 of 46 (`asyncgen.js`). Not made: `yield*` in an async generator (delegates
synchronously).
NEXT, for await (bbc's last SyntaxError): in s_each/s_for, after `for` accept keyword `await` (id 36) and translate
`for await (D of E) S` as: E; call prelude `__aiter(E)` (E[Symbol.asyncIterator]() or, failing that, a wrapper over the sync
iterator); loop: DUP, GETP next, CALLM 0, await it (OP_YIELD, through __awrap in an async generator), DUP, GETP done, JT to the
end; GETP value; assign to D as for..of does; S; JMP loop; end: POP the result, POP the iterator. break/continue: the loop
record as for..of keeps it (one place on the machine stack: the iterator). Read s_each first: reuse its target assignment.

**Thirtieth unit [by Opus]: for await (2026-11-13).** compile.S s_for takes `await` before `(` ([sp,#20]); s_each at 90: emits
it = __aiter(E), 0; each round PICK 1, __astep, await (c_await_op: through __awrap inside an async generator), DUP, __adone,
JF / POP / JMP out, __aval, then joins for..of's assignment at 91. New helpers c_callg1 (call a global with one argument) and
c_await_op. prelude.js: __aiter (Symbol.asyncIterator, else a wrapper over the sync iterator awaiting each value), __astep,
__adone, __aval. 47 of 47 (`forawait.js`).
FOUND (older, not fixed): a generator (function*, any kind) made INSIDE another function, whose body has let/const, comes out
undefined: `function f(){var h=function*(){const z=4};console.log(typeof h)}f()` prints undefined. Plain and async functions
are fine; top level is fine. Narrowed (unit 31 probes): only a DECLARATION `function* h(){let z}` inside f; the expression form
`var h=function*(){const z}` works, and `var z` inside works. `var h; function* h(){let z}` still leaves h undefined, and a
pre-scan change (skip the star) did not help, so the scan declares h; the hoisted store (c_hoist: CLOSURE + c_store of
c_function's [sp,#96]) or the constant it makes is what goes wrong. Next: check what c_hoist writes for this case.

**Thirty-first unit [by Opus]: declared generators inside functions (2026-11-13).** Cause: c_scan_block's "a name was awaited
and something else came" reset the declaration state at the `*` of `function* h`, so h was never declared in the outer
function ahead of time, and declaring it late collided with h's own variables. Fix: the star does not count there.
`function f(){function* h(){let z}...}` now works. 47 of 47 (case added to forawait.js).
bbc.com/news after unit 31: 58 run, 2 failed (both the piano SDK's own deliberate errors).

**Thirty-second unit [by Opus]: the live screen keeps the page's world (2026-11-13).** host/browse.c: with_scripts can hand
its `scripts` back (keep); serve keeps it as `live`, and every 50 ms scripts_tick runs the timers that are due by the real
clock, writes the tree out again, and if the page text changed throws the drawn strips away and redraws ("the page changed
itself"). Checked: a page with setInterval 6 s (through httpbin.org/base64) changed itself four times in 30 s. Not yet: a tap
reaching the page's dispatchEvent (needs the page piece to say which tree node is under a point); pictures are not re-fetched
after a change.

**Thirty-third unit [by Opus]: a tap reaches the page's click handlers (2026-11-13).** dom/document.js: __mark(on) sets or
removes `data-trough-click=N` on elements with a click listener or onclick; __tap(N) dispatches a bubbling click. host:
scripts_page writes the drawn copy with marks on, takes them off again (scripts never see them), and puts
`<a href="trough-node:N">` around each marked element's content (closing tag found by counting the same tag name). A tap
whose link is trough-node:N runs __tap(N) and forces a redraw. Checked: a button page through httpbin, three taps, "pressed
1..3" drawn. Not yet: listeners on document/body only (delegation: the tap has no node), and marked content is drawn in the
link colour.

**Thirty-fourth unit [by Opus]: a listing of translated programs (2026-11-13).** `checks/dis.py ENGINE file.js [from [to]]`
loads the file on the bench (no run) and prints every instruction of the world's code with its operand; jumps show their
target. Names and operand sizes come from the .S sources (the `+ N bits` notes on .equ lines or handler labels, else the
handler's U16/U8/FAR reads), so it follows the engine. 0 undecodable over the whole prelude. The prelude comes first: grep
for the instructions you want, or pass a range.

**Thirty-fifth unit [by Opus]: delegated clicks (2026-11-13).** dom/document.js __mark: when document, body or window listens for
clicks, buttons, [role=button], [tabindex], summary and [data-href] outside links are marked too, so a tap reaches the page's
delegated handler with the right target (e.target.closest works). Checked: a span role=button with a document listener.

**Live screen on real sites (2026-11-13) [by Opus].** Wikipedia's timers filled the 32 MB world within a minute (thousands of
"the world is full"). host: a full world now marks the page dead once (its scripts stop, the page stays); ticks every 200 ms;
TROUGH_KEEP_PAGE=file saves the drawn copy and says how many elements are clickable. NEXT: the garbage collector (plan at the
end of intent.md).

**Thirty-sixth unit [by Opus]: the garbage collector (2026-11-13).** `gc.S` (new, included after world.S), as planned at the end
of intent.md: conservative, non-moving mark-sweep. No block heads: a start bitmap (one bit per 8 heap bytes) gives each block's
extent; a mark bitmap; a mark stack (overflow: flag and rescan). World header 656 bytes (592-655: W_NBASE, W_HEAP0, W_BITS,
W_MARKS, W_MSTK, W_MSCAP, W_FREE, W_GCS; 584: W_LAST, the newest block made at the top). w_alloc: bump (sets the start bit),
else w_slow: every register saved on the processor's stack (roots), free list first fit (zeroed, split), else collect, then
bump, then fit. Roots: header, constants, globals, value stack, processor stack from sp to W_NBASE (set by ENTER for worlds).
A word counts as its low 48 bits and as an address. Sweep coalesces unmarked runs; a run at the top lowers the top. The
translator's three hand-made heap moves (c_strconst undo, string literal trim, units copy-down) now go through w_cut and only
when their block is W_LAST. Checked: 47 of 47 in the normal and the smallest (1 MB) world; a 100000-object loop in a 1.2 MB
world ran with 27 collections, right output; Wikipedia on the live screen 100 s with no full world (before: full within a
minute); bbc.com/news 58 run, 2 failed (unchanged).

**Measurement before shapes [by Opus] (2026-11-13).** Before building shapes, timed what they would speed up: 900k property reads
on an 8-property object 0.14 s (qjs 0.12 s); 200k reads of globals among 3000 0.08 s (qjs 0.08 s: globals are slots already);
a 100000-statement script in a 32 MB world translates and runs in 1.1 s. "the program is too big" seen on the bench came from the
bench's 1.2-2 MB world (code room is a world's eighth), not a limit real pages meet. So shapes are NOT the bottleneck now; they
move down the list. NEXT: the real-site failures (bbc.com/news 2 scripts failing, its run-time "not a function"), then live
background watching on more sites.

**Thirty-seventh unit [by Opus]: Reflect (2026-11-13).** bbc.com/news's two "failed" scripts are the Piano paywall SDK: its feature
test (`typeof Proxy`, Promise, includes, closest) fails on Proxy, so it takes its old-browser path, which throws on purpose. Reflect
(13 functions) added to prelude.js; checks/programs/reflect.js; 48 of 48. NEXT: Proxy in machine code (an object kind whose
get/set/has/delete/apply/construct go to the handler, in m_getprop, m_setprop, i_in, m_delprop and the call path).

**Thirty-eighth unit [by Opus]: Proxy (2026-11-13).** A proxy is an object of kind 7 (lib.S n_proxy, __n(67)) holding a getter
and setter pair at 32/40; m_getprop and m_setprop hand back a T_ACC value for that pair for ANY name, keeping the name in W_PKEY
(world 656; header now 672 bytes; __n(68) reads it), so the usual getter/setter call path runs the prelude's trap (get/set, or
plain forwarding). A proxy of a function is a wrapper function calling handler.apply. Not yet: has, deleteProperty, ownKeys,
construct traps; `in`, delete and Object.keys on a proxy see an empty object. checks/programs/proxy.js; 49 of 49. script.asm
promoted. bbc.com/news: the Piano SDK now passes its feature test and runs on, then a timer repeats "Cannot read properties of
undefined (reading 'push')" at ran-9.js column 493195 (`this.events.push` in addHandler; `this` may be a proxy from its DI
container). NEXT: find that (TROUGH_KEEP_ALL=/tmp/ka keeps every script).
BBC follow-up [by Opus]: the failing call is `pn.addHandler("logout",...)` from a setTimeout in ran-9 (Piano); `this.events` is
missing, so `pn` holds addHandler without the instance's fields. pn is filled from a DI container (`pn.X=pn.container.resolve`,
and q.resolve wrapped in a function Proxy whose unregistered tokens resolve to a get-everything Proxy). Not found yet how
addHandler reaches pn; parked as low value (paywall only; the page's content is unaffected). Suspects: for..in over an instance
(m_keylist), the function-proxy wrapper losing the target's own properties (q.resolve.x).

**Open: a crash, found 2026-11-13 [by Opus].** NPR (www.npr.org): the shipped engine reports 299 "SyntaxError: Unexpected token in
JSON (line 1, column 46376)"; a build differing ONLY in prelude.js line 78 (JSON.parse wrapped in try/catch with a console.log)
reports none of them and then SEGFAULTS (reproduced twice). gdb: in w_alloc (`str x0,[x19,#208]`), called from j_number (json.S,
`sub x13,x23,x15` before the string alloc), with x19 = 0x5555559410 and x21 = 0x5555559160: both inside out/browse's own text,
i.e. host register values, so an entry's epilogue (or an unwind to a saved frame, W_NSP) ran and the piece carried on. Suspects:
j_err / the native-throw unwind through W_NSP when builtin calls nest; w_slow + gc_collect during a JSON read. The debug build
is in /tmp/dbg2 (s.bin). The JSON errors and the crash are probably the same fault. NEXT: reproduce on the bench (fetch NPR's
JSON bodies: TROUGH_KEEP_ALL, or log the fetch URLs) and fix; this outranks the paywall bugs.
Crash follow-up [by Opus]: (1) FIXED a real collector fault: gc_collect took the value stack's top from W_SP, which the machine
writes only when it stops; while running the top is x22, so live values above a stale W_SP were not roots. Now the higher of
W_SP and x22 (when x22 lies inside the stack). 49 of 49. (2) The NPR crash is NOT cured by it: the debug build (prelude line 78
wrapped: try{v=p(s)}catch(e){console.log(...);throw e}) still segfaults on npr.org before printing anything, with the fixed gc.
On the bench every variant of that wrapper behaves (one earlier bench run printed only the first console argument and lost the
rethrow, not reproduced since: layout-sensitive corruption). (3) Repeated big JSON.parse in a 4 MB world says "full" (8 MB is
fine): probably fragmentation of the non-moving collector, not a leak. NEXT: replay NPR offline (save its scripts and fetched
bodies) so the crash can be caught under gdb with the world dumped; check j_err's unwind (W_NSP) and the reviver walk.
Crash, second look [by Opus]: at the fault sp == x29 == a HOST frame (saved lr 0x55555523b4 = browse.c's return from
with_scripts), x19/x21 point into browse's .rodata (0x9410/0x9160), x22 into the host heap, x24 (JSON end) is right. So the
processor stack was set back to the host's frame while a JSON read went on: something restored a stale sp. Checked and NOT it:
n_fail/n_full (sp from W_NSP, set at the only builtin dispatch, lib.S:66), the JSON nesting guard, j_number's own frame.
Suspects left: anything that saves and later restores sp or a frame across runs (generator/async snapshots, OP_GENSNAP; the
__host round trip; try records holding sp). Gdb recipe: `cp /tmp/dbg2/s.bin out/script.asm.bin; gdb -batch -ex run -ex 'x/24gx
$sp' --args out/browse out https://www.npr.org /tmp/x.png` (restore script.new.bin after).
Also checked, not it: regex translator (saves and restores x20-x28 on every way out; only `mov sp, x29` frame resets).
Crash, third look [by Opus]: hardware breakpoints on all seven sp-reset instructions (compile c_fail, n_full, n_fail, regex
exits; condition: new sp == the host frame 0x7ff7fb7bf0) did NOT fire before the fault; a trap build (/tmp/dbg2: brk when
sp > W_NBASE at every builtin dispatch and w_alloc) faulted in w_alloc before its check could run. So the likely story: an
ENTER frame's saved registers/lr were overwritten, LEAVE restored host x19-x28 and "returned" into JSON code. Next: a watch on
the ENTER frame's saved x30 conditioned on $pc inside the piece (0x7ff7362000-0x7ff7382000), set after the first `run` entry
(watching from main is swamped by host writes); also review regex.S:439/1048 (variable `sub sp`) and lex.S:517.
Crash, fourth look [by Opus], PARKED: a watch on 0x7ff7fb7b88 limited to the script piece's code (0x7ff7362000-0x7ff737c000;
the piece mapped after it, at +0x1a000, is a different one) never fired, so the "overwritten ENTER frame" guess is unproven
(the frame's address was assumed from the crash sp). The shipped engine does not crash on NPR; only the debug-prelude variant
does. Parked after four turns because the cost was rising without narrowing; next time start by recording every ENTER's sp
and every LEAVE's (a ring in the world header, debug build only) and comparing with the crash.

**Thirty-ninth unit [by Opus]: DOM names (2026-11-13).** dom/document.js: NodeList and HTMLCollection (prototype = Array's, as
our lists are arrays), HTMLDivElement and eight more element names aliasing Element. Guardian: the NodeList failure is gone;
now its polyfill bundle (ran-8.js, sent because our user agent is unknown) reads `document.documentElement` with `document`
undefined at line 157 although nothing in the bundle shadows it: NEXT, find why (the bundle runs inside (function(self){..})
(window); a polyfill may redefine something on window). Also open: Guardian 'g' of undefined (line 1, column 42258); GitHub
runs 0 scripts (modules, probably); NPR 299 JSON errors.

**Fortieth unit [by Opus], begun (2026-11-13): run-time `new Function` / `Function(...)`.** Found: Guardian's polyfill bundle
runs `new Function("return function Document() {}")()`, and our `Function` is an empty prelude stub, so it returns an object and
the bundle fails later (the "document undefined" report was this). Plan: a built-in `__compile(text)` that calls a variant of
c_compile mid-run: code appended at W_CODE_LEN, names scratch (F_NTOP) above the live value stack (max(W_SP, x22)), no
W_HANDLER/W_STATE/W_PC changes, no jobs epilogue; text wrapped as `function anonymous(ARGS\n) {\nBODY\n}` and translated with
c_function (kind 0), whose OP_CLOSURE constant is then made a function with the global scope (as i_closure does, x28 = 0).
Save x19-x30 around it; errors become SyntaxError. Then prelude `Function` uses it. Not started in code.
Live screen (same day): the page world on Wikipedia filled after a while (cause not found; host now reopens a full page once a
minute). Suspect each tick's two `__mark` loads (code appended, never freed) and __mark's allocation.
Done in the same unit [by Opus]: `__compile` (lib.S n_compile, #69) over `c_fragment` (compile.S); prelude `Function` uses it
(one-byte text only). The Guardian's real fault was elsewhere: c_scan_block kept a `var` list open across a line break, so
`var n=1` NEWLINE `return f(),D` declared D as a local; a statement-only keyword (mask 0xc6a14063) now closes the list.
dom: document.implementation. Guardian 15 scripts, 1 failed (ran-9 'g'). host: TROUGH_SWAP=dir runs dir/swap-N.js in place of
script N (probe a live page's script). 50 of 50 programs (checks/programs/runtime-function.js).
Side bug [by Opus, 2026-11-13], open: the first byte of a program's printed text sometimes loses bit 5 ('function' printed as 'Function') in programs that print more than one line; out region follows globals in the world; nothing found clearing bit 5 yet.
Narrowed [by Opus]: `console.log("function");console.log("function","x")` prints "Function" first (only the very first output byte, only with the same text again in a two-argument log; "abc" does not do it). Constant dedupe (c_strconst) and toUpperCase checked: not them.
GitHub [by Opus, 2026-11-13]: all 13 of its scripts are `type="module"` (plus an importmap), so none run. Next big unit: modules.
Plan: host (browse.c) runs module scripts too, after classic ones, in document order, deferred; the engine translates
`import ... from "x"` / `export ...` into a per-module record: each module's body wrapped as a function taking its import
bindings, run once its dependencies have run; specifiers resolved by the host (importmap, then url resolve) and fetched
through the existing __host round trip; `import()` returns a promise. Live bindings can start as copies (note it).

**Forty-first unit [by Opus], begun (2026-11-13): modules.** Host step done: browse.c defers `type="module"` scripts and runs
them after the classic ones (a second pass once no new classic scripts appear). GitHub now: 2 run, 3 failed (module syntax:
"not made yet" at `import`). NEXT, in compile.S c_stmt: `import {a, b as c} from "x"` -> const bindings from `__import("x")`
(default -> .default, `* as ns` -> the record); `export` before a declaration -> the declaration plus a record entry;
`export default e`; `export {..}`; host `__import` resolves (importmap, url) and fetches via __host; modules wrapped so their
top-level names stay their own.
Unit 41, stage 1 done [by Opus]: compile.S c_stmt reads `import ... from "x"` / `import "x"` (binds nothing yet; `import(`
and `import.` stay expressions) and `export` (default, declarations, `{..} [from]`, `* from`; nothing recorded). lex.S: `#name`
lexes as a name keeping its `#` (private names work as ordinary properties; not yet private, `#x in o` not made).
checks/programs/private-names.js; 51 of 51. GitHub: all scripts translate, 5 run, 3 fail at run time on unbound imports
(`import * as e from "react"`, resolved through its importmap). NEXT: stage 2, bindings and loading as planned above.
Unit 41, stage 2a [by Opus]: `import d, {a as x, b} from "m"`, `import * as ns`, `import "m"` translate to
`__module("m")` (one call per statement) with each name copied out (var-like, not live; default from `.default`). The prelude
has no `__module` yet (dynamic `import()` keeps the separate `__import`). NEXT: exports (a module body run with an exports
record; `export` declarations, default and lists put their names in it) and `__module` in dom/document.js: importmap, resolve
against the importing module, fetch through __host('f'..) (the 16-request cap must not count modules), translate once with
__compile, cache by address.
Unit 41, stage 2b [by Opus]: exports (compile.S s_export, c_expget/c_expset/c_isfrom/c_isas; c_var copies `export
const/let/var` simple names via bit 0x100 of F_DECLKIND; export function/class/default/{list}/{list} from; `export *` still
skipped) into `__exports`, the module body's parameter. Loader: dom/document.js `__module` (importmap exact and prefix,
cache by final address, import.meta.url while a module runs, `__import` for import() now resolves); host 'M base\nspec'
request (no 16 cap, 300 modules) answering "1address\n text"; module scripts with src run as `__module("src")`.
GitHub: modules load and run; now fails on `URL` missing and 'C' of undefined (line 4 col 4830). 51 of 51.
NEXT: URL class in document.js; the 'C' failure; `export *`; live bindings are copies (circular imports see partial records).
Unit 41, stage 2c [by Opus]: URL and URLSearchParams in dom/document.js (checks/programs/url.js matches node); module
translation errors name the module; `delete a?.b` / `delete a?.[k]` (compile.S: F_DEL at frame 216, c_postfix frame 112, the
last read becomes DELP/DELE, a chain that gave up gives true; checks/programs/delete-optional.js). checks/runhuge.py = runbig
with a 200 MB world. 53 of 53. GitHub now: f18 module needs `new Function` over two-byte text (n_compile: one-byte only);
landing-pages fills the 32 MB world. NEXT: two-byte text for __compile; a bigger page world (or gc during translation);
'length' of undefined at line 4 col 86259.
Unit 41, stage 2d [by Opus]: __compile takes any text (lib.S n_compile makes text past ASCII UTF-8 first with strings.S
w_enc, split out of w_outs; this also fixes one-byte text with Latin-1 characters, which was read as broken UTF-8);
c_pattern keeps up to 200 keys before an object rest (was 32; frame 224 + 672); page world 96 MB (browse.c).
checks/programs function-wide.js, rest-many-keys.js; 55 of 55. GitHub: primer-react and react-core translate; now f18 and k0
hit "not made yet" (find with checks/runhuge.py on the module wrapped in `function __m(__exports){..}`; fetch with python
urllib, no curl here). Module error line numbers are wrong (always 210, 11): fix c_fragment's line counting.
Unit 41, stage 2e [by Opus]: class declarations are let-like (c_class sets F_DECLKIND 1 around c_declref), so a class in an
inner block with its own scope no longer hits c_declare_in's "not made yet"; object rest after computed keys (c_pattern looks
ahead for a rest at its own level, frame 888; worked-out keys go to the prelude's __rkeep, the rest calls __rest2(value, m,
named..)); a computed key the translator folds to a number (`[1+1]`) with a rest is still "not made yet"; objects.S
m_keylist skips symbol keys (texts starting with unit 1), so Object.keys / for-in no longer list them; getOwnPropertySymbols
still returns [] and a rest does not copy symbol keys. Debug trick: /tmp copy of compile.S with each c_notyet given its own
message ("notyet at LINE"). checks/programs rest-computed.js, class-in-block.js; 57 of 57. GitHub: k0 fine; f18 now
"Unexpected token"; 'length' of undefined at line 4 col 86259 (twice).
Unit 41, stage 2f [by Opus]: names may hold \u escapes (lex.S w_uesc; c_wordconst decodes such a name as a string; variable
names compare raw text, so `xy` and `xy` are different variables still); dom/document.js: DocumentFragment and other
element names, IntersectionObserver / MutationObserver / ResizeObserver / PerformanceObserver that never report.
checks/programs/name-escapes.js; 58 of 58. GITHUB: EVERY MODULE TRANSLATES now. Run-time: `DataView is not defined` (no
typed arrays at all in the engine: ArrayBuffer, Uint8Array.., DataView), after which a webpack runtime fails 300 times
('call' of undefined, line 4 col 156, probably from timers); 'illegal invocation' at line 138 col 160598.
NEXT: typed arrays and DataView (engine, machine code: a byte block kind; element get/set by type), then recheck GitHub.
Unit 42 [by Opus], stage 1: typed arrays and DataView in prelude.js (comment above the code states the limits: views other
than a whole-buffer Uint8/Int8 are copies; index writes are not wrapped to the kind; no BigInt64 kinds); IEEE encode/decode
written in the language (exact 64-bit decode in two 32-bit halves); Math.fround if missing. checks/programs/typed-arrays.js;
59 of 59. Machine-code typed arrays (a byte block kind with typed element get/set) are the proper stage 2.
GitHub after it: 'set' of undefined (line 4 col 1018), then 'call' of undefined x300 (line 4 col 156), 'illegal
invocation' (line 138 col 160598).
Unit 43 [by Opus]: block scoping in c_scan_block. A let/const inside an inner block, or in a for statement's head (the text
before it is a bracket), is no longer taken as the whole function's variable (it hid outer variables of the same name: GitHub
4u's `for(let a of ..)` made `a` local to addFile). checks/programs/let-shadow.js; 60 of 60. Wikipedia 8/0, Guardian 18/1.
OPEN, seen today: BBC news 58 run / 299 failed, 298 of them "'push' of undefined" at line 1 col 493195 repeating (timers?);
same with the engine as pushed before this unit, so it came earlier (modules? typed arrays? document.js?): bisect next.
GitHub: 'not a function' line 4 col 64207; 'call' of undefined x300 (wp-runtime: a webpack module id missing); 'illegal
invocation' line 138 col 160598. Runtime errors in modules do not name the module (add it like the translation errors).
Bisect [by Opus]: BBC's 299 failures are the same with the engine of 6dd9a76 (before today's work): BBC changed, not us. It is
the known paywall `addHandler` with `this` undefined (ran-9.js), repeated by timers. Run-time errors thrown while a module's
body runs now say "(running URL)" (dom/document.js __module). GitHub: illegal invocation (running core-..js) and not a
function (running landing-pages-..js); their line/column do not match those files (the throw site is elsewhere, perhaps in
code the module called): errors need a call trail (e.stack) to be findable. Parked GitHub here for the older list.
Side bug (first output byte losing bit 5, "Function"): no longer reproduces with today's engine (/tmp/fj/a.js printed
"Function" early in this session, "function" now); cause not identified (today's changes near output: w_outs split into
w_enc). Kept as checks/programs/first-byte.js to catch a return.
NPR [by Opus]: its 299 "Unexpected token in JSON" are one JSON.parse of a JSONP reply (`jsonFeed({...});`, 80 bytes, a geo
lookup) repeated by a timer; the column is the calling script's, not the text's. Low value (the site's own fallback).
NEXT (older list): the live screen's page world filling on Wikipedia (measure headless: run scripts_tick in a loop and watch
W_HEAP / code length); Proxy has/deleteProperty/ownKeys; e.stack (a call trail) so run-time errors can be found.
Proxy [by Opus]: ownKeys (Object.keys, getOwnPropertyNames, Reflect.ownKeys), has and deleteProperty (through Reflect only;
`in` and `delete` do not reach traps) for objects made by Proxy (a Map __proxies; Object.keys pays one size check when no
proxy exists). checks/programs/proxy-traps.js; 62 of 62.
Live world [by Opus]: browse.c TROUGH_TICKS=N runs N live ticks after a one-shot load (200 ms apart, every fifth forced as a
tap does) and prints heap top/end and code length every 25. Wikipedia Moon: heap top is AT its end from tick 0 (the load alone
reaches 96 MB once, the collector reuses after that); code grows 14 bytes a tick (no danger); 100 ticks about 1 s each, not
slowing, not dead. The earlier "filling" was not reproduced in 100 ticks; a 1500-tick run hit the 600 s limit. Next look:
the collector's live total (sum the free list) per tick, and why loading the page needs 96 MB.
World size [by Opus]: browse.c tick report now sums the collector's free list (free_total). Wikipedia Moon after load: 84
collections during load, about 47 MB free in 14214 blocks, so about 50 MB held (conservative marking; Chrome holds ~5-10 MB
for this page, so retention or bulky representation is likely). Idle ticks make ~370 KB of garbage each, no collection in 50.
"Needs 96 MB" is partly policy (the top grows to the end before collecting). Next look: a size histogram of marked blocks
after a collection, to see what the 50 MB is (script texts? compiled-from strings? the tree?).
World size, answered [by Opus]: of the 96 MB, about 31 MB is fixed regions before the heap (code room 12.5 MB etc., scaled to
the world). Held after load is only ~18.5 MB (held_sizes in browse.c: 9.3 MB in 98 blocks of 64 KB+, likely kept script
texts; 2.5 MB in 142k blocks of 16 bytes). The 47 MB "free" is just the collector waiting for the top to reach the end.
TROUGH_WORLD_MB=N picks the size: 64 and 48 both load Wikipedia Moon fully (129 and 188 collections, not dead). Wikipedia does
not need 96 MB. Possible next: a smaller default once collection time is measured; kept 64 KB+ texts could be dropped.
Unit 44 [by Opus]: CALL TRAIL. Each call record's word 7 now packs the caller's place (kind 8 bits, line 24, column 32); a
return puts W_POS back to the caller's place (errors after a call in the same statement were reported inside the callee).
m_trail (machine.S) keeps W_TRAIL/W_TRAILN (header now 800 bytes) at every m_raise/m_fail; __n(70) = `__trail` (prelude)
gives it as numbers line*2^32+column; Error's stack lists every caller; document.js module errors say "called from L:C ...".
checks/programs/trail.js; 63 of 63. browse.c: TROUGH_WORLD_MB, free_total, held_sizes. GitHub now shows 12-deep trails, but
places carry no script identity (138:160598 is in none of core.js's lines): NEXT give each translated text a number and pack
it into the place (or keep a code-offset -> text table), then read GitHub's two errors.
Unit 45 [by Opus]: places carry their text's number (W_TEXTNO at 800, header 808; c_pos puts it in bits 24-31 of the line;
record word 7 is now kind 4 bits, line 20, text 8, column 32; __trail numbers are text*2^44+line*2^24+column; __trail(0)
gives W_TEXTNO). document.js names module texts (__texts) in "called from"; browse.c prints "script: trail tN:L:C" for
classic scripts and keeps them as ran-R-tN.js. Found with it on GitHub: (1) TextEncoder/TextDecoder missing (added to
document.js, UTF-8); (2) TRANSLATOR BUG: c_scan_meth missed a method written short inside a call's brackets
(`f({m(e){..}})`), so the outer function's variables stayed on the stack and the method read garbage after return; fixed
(bit 16 of the scan state). checks/programs/meth-in-args.js; 64 of 64. GitHub: 302 failed -> 2 (both with an empty message,
ran-2 and ran-4: next look). Wikipedia 8/0, HN 1/0, Guardian 18/1 unchanged.
Unit 46 [by Opus]: Object.getOwnPropertyDescriptor gives {get,set} for accessors (built-in 71 n_ownacc, lib.S) instead of
calling the getter (GitHub f18's CommandEvent polyfill re-defines `source` and its getter threw "illegal invocation").
Enumerable is still always true (class members should be false). checks/programs/accessor-desc.js; 65 of 65.
GitHub's two remaining module errors (both "not a function"; host shows an empty message, cause not found yet):
core runs into f18 225:8764 `C=new S.dw` (an imported class missing: S is a webpack module); landing-pages into 4u
4:51067. NEXT: why S.dw is missing (a module not loaded or an export getter); why the host prints an empty message.
Unit 47 [by Opus]: (1) c_scan_block: `class X` at a statement's start in a function body is that function's variable from
the start (an arrow written before it reached a global instead; GitHub's webpack getters `dw:()=>b`). class-hoist.js.
(2) OP_SUPERTHIS (97; OP_COUNT 98): after super(..) the parent's answer, if an object, becomes `this`. super-return.js.
(3) document.js: template .content, AbortController/AbortSignal, CUSTOM ELEMENTS (createElement and define upgrade: the
prototype is swapped and the class constructed with Element's constructor answering the element; connectedCallback on
define for elements already in the tree). 67 of 67. GitHub core now reaches f18 relative-time ('call' of undefined in
its constructor, 12 times) and 'distance' of undefined; landing-pages still primer-react 4:153114 not a function.
Unit 48 [by Opus]: named class expressions (`var a=class e{.. new e ..}`) get their own name in a block of their own
(c_primary: c_block_in, c_class as a declaration, c_block_out). class-expr-name.js; 68 of 68. document.js: attachShadow,
attachInternals (GitHub relative-time now constructs). GitHub now: core stops in color-convert ('distance' of undefined)
because Object.defineProperty(..,{value}) makes ENUMERABLE properties (channels/labels show up in Object.keys): NEXT is a
non-enumerable flag per property (idea: a bit in the key word above the 48-bit offset; o_keyeq must mask it; KEYS skips it;
defineProperty default enumerable false; class methods non-enumerable). Landing-pages now stops on BigInt (not defined):
BigInt is a large stage of its own (the lexer already reads 123n as kind 8).
Unit 49 [by Opus]: NON-ENUMERABLE properties: a key word tagged 0xfff8 (n_hide, built-in 72; the key lister in objects.S
skips it; o_keyeq and the collector are unaffected). Object.defineProperty hides unless enumerable (not on arrays).
hidden-props.js; 69 of 69. Still missing: writable/configurable; class methods non-enumerable; getOwnPropertyNames omits
hidden ones. document.js: domain, URL, Blob/File (text only); .content only for <template> (meta.content is the attribute).
GITHUB: core runs clean; 1 failed script left: landing-pages needs BigInt. Wikipedia 8/0, HN 1/0, Guardian 18/1.
NEXT: BigInt (a stage of its own: the lexer reads 123n as kind 8; plan in intent.md first), or the Guardian's 1.

### Unit 50 [by Opus] (2026-11-13): GitHub moves past BigInt
BigInt stage 1 in prelude.js: BigInt(x) from number/string/hex/bool, exact decimal text in `_s`, toString/valueOf, errors as node;
typeof is still "object", no 123n literals (c_notyet), no operators (they go through valueOf, so lossy past 2^53). Stage 2 = real
values (a tag), literals, operators. Native 73 n_defval (lib.S): Object.defineProperty with a value puts the own property directly
(it called the setter before; zod's lazy getters recursed forever). getOwnPropertyDescriptors. compile.S c_function saves and zeroes
F_DECLKIND (frame 248): function declarations inside any function in a const's value were const (Babel's wrapNativeSuper threw).
document.js: toggleAttribute, getAttributeNames (empty: no .attributes yet), crypto (Math.random: NOT secure), __trs() call trail
on connectedCallback errors. 72 of 72 programs.
GITHUB now: landing-pages fails "reading '_zod'" at its line 723:313825 (u.Brp from module fS in chunk 97 is undefined). A harness
(/tmp/h.js: chunks 97+8d modules with a mini webpack require, built by node) gives the same as node in runhuge, so the cause is
page-side: suspect a module that threw half-way, or a let read before its value (we give undefined, not ReferenceError: TDZ).

### Unit 51 [by Opus] (2026-11-13): enumerability kept on redefinition; a collector fault found
Object.defineProperty without `enumerable` on an existing own property no longer hides it (spec: absent attributes keep their
value). zod's $ZodObject redefines `shape` as a getter: `{...def}` lost it, so object shapes were empty. redefine.js; 73 of 73.
Way of finding faults inside page modules: python edits of out/document.js's __module (r=r.replace(anchor, probe) for one url),
markers `,Qn=console.log("Mn"),` between a long let's declarators; restore with cp dom/document.js out/.
COLLECTOR FAULT (next, high): on github.com with the default world, chunk 97 module uk's local `function o` reads typeof
"function" but String(o) is "[object Object]" and calling it throws "an object is not a function"; with TROUGH_WORLD_MB=400 it
does not happen. So a function object's plan/closure is damaged by a collection. Reproduce in a bench: /tmp/h2.js style harness
(chunks via node, mini require) in a small world with many collections.
After that on GitHub (400 MB world): RegExp with \p{RI}, \p{Emoji}, \p{EMod}, \u{...} and flag u (landing-pages 426:122916).
Unit 52 [by Opus] findings (no code change): the GitHub "an object is not a function" (97 module uk, statement at 58:52285,
`let n=\`${o({...})}...\``) happens ONLY at TROUGH_WORLD_MB=96 (the default); 64, 80, 112, 128, 200, 400 all pass it. It is
deterministic at 96, and any probe code in that module hides it (allocation timing). Bench harnesses (node-built chunk
harness, new Function closures under garbage at 8-40 MB) do not reproduce it. Leading suspects: a root the collector misses
during run-time compiling (c_fragment keeps names above the value stack top; string-literal double copy + w_cut in compile.S
~2440-2490 relies on W_LAST adjacency across a possible collection). NEXT: a collection-stress switch (collect every N slow
allocations, or keep W_HEAP_END just above the top) so the fault shows up in small bench programs; then fix.
Probe tip: JS String.replace treats $` and $' in the replacement specially; use r.replace(a,function(){return b}).
Also seen: nf3-style plain closures + 20k-object garbage rounds fill a 24 MB world (40 MB fine): retention worth a look.

### Unit 53 [by Opus] (2026-11-13): collection stress switch; Unicode regular expressions; GitHub 0 failed at 128 MB
world.S: header 824 bytes; W_STRESS (808) / W_STRESS_END (816): w_slow with stress set skips the free list, collects, and keeps
W_HEAP_END at top + step + the size wanted. host/browse.c TROUGH_GC_STRESS=bytes sets it (8 MB on GitHub: very slow).
prelude.js __rxu: flags u/v translate the pattern for the 16-bit engine: \u{...}, astral literals and class ranges as surrogate
alternatives (full high-surrogate spans collapsed), . matches a pair, \p{..}/\P{..} from a small table (RI, Emoji, EMod,
Extended_Pictographic, L, Lu, Ll, N, Nd, P, White_Space; unknown names: everything past ASCII). Negated classes with astral parts
are BMP-only. rxunicode.js; 74 of 74.
GITHUB: TROUGH_WORLD_MB=128 -> 5 scripts run, 0 failed. At 96 (default) still "an object is not a function" (unit 52 notes).
Unit 54 [by Opus]: m_notfn_o keeps the called object's distance at world+824 (W_BADCALL; header now 832); browse.c
TROUGH_BADCALL=1 prints it, the collection count and the object's first 12 words after a script error. With this build GitHub
runs 5/0 at 72, 84, 90, 94, 96, 98, 102 MB: the fault no longer shows (layout-sensitive). Not fixed, only not seen: when
"an object is not a function" appears anywhere, rerun with TROUGH_BADCALL=1 and read the words (kind word should be 1).
Sites: Wikipedia Moon 8/0, HN 1/0, Guardian 18/1 (unchanged).
Unit 55 [by Opus]: Guardian 18/1 -> 29/0. (1) host/browse.c: a tree question ('d') no longer counts as a turn of the 200000
(big pages walk parents hundreds of thousands of times; "stopped after too many steps" was that), capped at 50M questions.
(2) prelude.js: Array forEach/map/filter/some/every/find/findIndex take thisArg (they ignored it; IntersectionObserver polyfill).
thisarg.js; 75 of 75. Sites: Wikipedia 8/0, HN 1/0, GitHub 5/0, Guardian 29/0.
NEXT candidates: BBC, NPR (old notes say the sites' own faults); BigInt stage 2 (typeof, literals, operators); the collector fault.
