# script: the map (made by tools/scriptmap.py; do not edit)


## world.S (145 lines)
The world: everything a running program has, in one block the host owns (kind 6). Nothing in it is an address: every reference is a distance from the block's start, so a world can be moved, saved, or handed to a new build of this piece. x19 is the world's start wherever this file's routines are used.
- 43 `VAL` VAL: a tagged value with no payload -> \reg
- 49 `w_begin` w_begin: makes the block at x19 a fresh world -> x0 1, or -1 if it is not a world block or is under a megabyte. The room is shared out by size: an eighth for instructions, a thirty-second each for constants and globals, a sixteenth each for printed text and th
- 98 `w_alloc` w_alloc: x0 bytes of the heap (rounded up to 8) -> x0 where (a distance from the world's start), or 0 if the world is full. Uses x9, x10.
- 112 `w_string` w_string: a string value holding the x1 bytes at x0 -> x0 the value, or 0 if the world is full. A string in the heap is its length (8 bytes), then its bytes. Uses x9-x13.
- 131 `w_out` w_out: the x1 bytes at x0 join what the program has printed (what does not fit is dropped). Uses x9-x12.

## lex.S (932 lines)
script, written by hand (ARM64): Trough's own JavaScript engine. The meaning and the plan are script/intent.md. This file: the words (stage 1). Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table. Calls nothing. While words are being read: x20 the text, x21 how long, x22 where we are, w23 the word's kind, w24 its id (which keyword or punctuation), x25 where it starts, x26 how long it is, w27 whether a line ended before it, w28 whether a slash here would begin a pattern, d8 a number's value. Kinds: 0 the end, 1 name, 2 keyword, 3 number, 4 string, 5 template, 6 punctuation, 7 pattern, 8 a number meant as a big
- 19 `CH` CH: the byte at x22 + \ahead -> \reg, or 0 past the end
- 29 `NAMEPART` is_name_part: can the byte w0 be inside a name -> flags: eq if so. (Letters, digits, $ and _; and any byte of a character beyond ASCII, which is taken as a letter for now.) Uses w9.
- 46 `next_word` next_word: reads the next word at x22 into w23-w27 and d8; moves x22 past it. Uses x0-x17.
- 48 `w_space` what is between words: spaces, line ends, comments
- 264 `w_quoted` a string: to the same quote, a backslash taking what follows with it
- 293 `w_template` a template: to the closing backtick; ${ ... } inside may hold anything, strings and
- 498 `n_exact` n_exact: the decimal number in the text from x25 to x22, with w12 the power written after its e, as the nearest double (ties to the even one) -> d8. The digits become one long whole number in 32-bit limbs on the stack (the first 800 that count; whether anythin

## values.S (345 lines)
Values and their conversions, as the language defines them. x19 is the world. These routines use x0-x17 and d0-d3 only. ISNUM: is the value in \reg a number -> flags: lo if so. Uses x17.
- 3 `ISNUM` Values and their conversions, as the language defines them. x19 is the world. These routines use x0-x17 and d0-d3 only. ISNUM: is the value in \reg a number -> flags: lo if so. Uses x17.
- 9 `TAGIS` TAGIS: has the value in \reg this tag -> flags: eq if so. Uses x17.
- 15 `STRV` STRV: where a string value's bytes are and how many -> \ptr, \len (the value in \reg, which may be \ptr)
- 22 `LIT` LIT: a string value for fixed text between two labels -> x0 (0 if the world is full)
- 28 `v_truthy` v_truthy: does the value x0 count as yes -> w0 1 or 0
- 53 `v_number` v_number: the value x0 as a number -> d0
- 77 `v_text_number` v_text_number: the string value x0 read as a number, by the language's rules for text: spaces at either end do not count, nothing at all is zero, a base prefix is allowed, Infinity is a word; anything else that is not wholly a number is not one.
- 265 `v_same_text` v_same_text: are the two string values x0 and x1 the same text -> w0 1 or 0
- 273 `v_strict` v_strict: are the values x0 and x1 the same without any conversion (===) -> w0 1 or 0
- 297 `v_loose` v_loose: are the values x0 and x1 the same after the language's conversions (==) -> w0 1 or 0

## strings.S (233 lines)
Text. A string in the heap is one word, then its units: the word's low 32 bits say how many units, bit 32 whether they are wide. A unit is one of the language's 16-bit code units. Text with no unit past 255 keeps one byte a unit; any other keeps two (wide), and a string is wide only if it needs to be: so two strings with the same text are the same bytes. u_next: the UTF-8 character at x11 (text ends at x12) -> w13, x11 moved past it. A byte that does not fit the encoding stands for itself. Uses x13-x17.
- 6 `u_next` Text. A string in the heap is one word, then its units: the word's low 32 bits say how many units, bit 32 whether they are wide. A unit is one of the language's 16-bit code units. Text with no unit past 255 keeps one byte a unit; any other keeps two (wide), an
- 64 `w_text` w_text: a string value for the x1 bytes of UTF-8 at x0 -> x0, or 0 if the world is full. A character past 0xffff becomes its pair of units. Uses x0-x17.
- 117 `w_unit` w_unit: a string value of the one unit w0 -> x0, or 0 if the world is full. Uses x9-x13.
- 133 `s_copy` s_copy: x13 units from x10 (wide if x12) to x8 (wide if x6); x8 is left after them. Uses x10, x13, x14.
- 148 `w_outs` w_outs: the string value x0 joins what the program has printed, as UTF-8 (a pair of units is one character; half a pair alone is printed as the replacement character; what does not fit is dropped). Uses x0-x12.

## num.S (422 lines)
A number as text, exactly as the language says: the shortest digits that read back as the same number (the method of Steele and White as put by Burger and Dybvig: whole-number arithmetic on long numbers, no approximation), then laid out as plain digits, a decimal fraction, or with an exponent, by where the point falls. Long numbers here are 24 limbs of 64 bits, lowest first (1536 bits: enough for any double's digits). bn_small: the long number at x0 becomes the small number x1. Uses x9.
- 7 `bn_small` bn_small: the long number at x0 becomes the small number x1. Uses x9.
- 16 `bn_times` bn_times: the long number at x0 times the small number x1, in place. Uses x9-x13.
- 30 `bn_shift` bn_shift: the long number at x0 times 2 to the power x1 (0 to 1200), in place. Uses x9-x14.
- 51 `bn_add` bn_add: the long number at x0 gains the one at x1. Uses x9-x12.
- 63 `bn_less` bn_less: the long number at x0 loses the one at x1 (which is not larger). Uses x9-x12.
- 75 `bn_order` bn_order: the long numbers at x0 and x1 compared -> flags as after "cmp first, second" for unsigned numbers. Uses x9-x11.
- 95 `BNP` macro reg, off
- 99 `num_text` num_text: the number d0 as a string value -> x0 (0 if the world is full)
- 339 `n_exp` very large or very small: one digit, a point, the rest, e, the power
- 397 `n_high` n_high: does r + up reach s (pass it, when the range's ends do not round to the number) -> flags: hs if so

## compile.S (2560 lines)
The translator: the program's words become instructions for the machine, in one pass, nothing kept as a tree. Expressions by precedence climbing; jumps are written with room for their distance and filled in when the place is known. While it works: x19 the world, x20-x28 and d8 the word reader's (the current word is always read already), x29 this translator's own frame, set once by c_compile and never moved: an error anywhere drops the stack back to it. Stage 2: names are all globals (no block scope yet); functions, objects, arrays and templates are refused as not yet made.
- 24 `ISP` ISP, ISK: is the current word this punctuation / this keyword; goes to \no if not
- 30 `ISK` macro id, no
- 37 `EXPECT` EXPECT: the current word must be this punctuation; steps past it
- 41 `OP` macro op
- 45 `NOLV` macro
- 49 `DEEPER` macro
- 56 `SHALLOWER` macro
- 63 `c_compile` c_compile: the text at x20, x21 bytes long, as instructions in the world -> x0 1, or -1 with the error left in the world
- 108 `c_out` 
- 112 `c_unexpected` the ways it goes wrong: the message, with the line and column of the word it stopped at
- 116 `c_notyet` 
- 120 `c_badleft` 
- 124 `c_noloop` 
- 128 `c_toobig` 
- 132 `c_toodeep` 
- 136 `c_full` 
- 139 `c_fail` 
- 171 `c_m_end` 
- 177 `c_w_end` 
- 179 `c_w_arguments_end` 
- 181 `c_prec` for each punctuation (by its id): how tightly it binds as an operator between two values (0: it is not one) and its instruction
- 192 `c_asg` for each punctuation: the instruction it applies when it assigns (0: it does not assign; 255: plain =)
- 200 `c_byte` Writing instructions. c_byte: the byte w0 joins them. Uses x9-x11.
- 210 `c_op16` c_op16: the instruction w0 with the 16-bit number w1. Uses x9-x11, x13, x15.
- 221 `c_jump` c_jump: the jump w0 with its distance left open -> x0 where the distance is to go. Uses x9-x11, x13, x15.
- 233 `c_patch` c_patch: the jump whose distance is at x0 lands here. c_patch_to: lands at x1. Uses x9-x11.
- 235 `c_patch_to` 
- 242 `c_jump_to` c_jump_to: the jump w0 to the place x1 (already known). Uses x9-x11, x13-x16.
- 250 `c_chain` c_chain: the jump w0 joins the chain whose head is at the address x1 (the chain runs through the open distances themselves).
- 260 `c_resolve` c_resolve: every jump of the chain whose head is x0 lands at x1. Uses x9-x13.
- 271 `c_const` c_const: the value x0 as a constant (one already there is used again), and the instruction that brings it. Uses x9-x17.
- 279 `c_addconst` c_addconst: the value x0 as a constant -> w0 which. Uses x9-x12.
- 304 `c_strconst` c_strconst: the same for the string value x0, which is the newest thing in the heap: if a constant already holds that text, it is used and the new copy's room goes back.
- 346 `c_is` c_is: is the current word exactly the x1 bytes at x0 -> flags: eq if so. Uses x9-x11.
- 360 `c_global` c_global: the global variable the current word names -> w0 which (made, holding undefined, if it is new)
- 409 `c_lvalue` c_lvalue: the variable that was just read by name, to be assigned to -> w0 the reading instruction as written (its bytes); anything else is an error. Uses x9, x11, x12.
- 432 `c_store` c_raw: writes the reading instruction w0 (as c_lvalue and c_ref give it). c_store: writes the storing one that matches it.
- 434 `c_raw` 
- 456 `c_lvdup` c_lvdup: before a property (whose reading instruction is w0, just written) is read to be changed and stored again, the object (and key) it is read from are doubled, so they are still there for the store. w0 stays. Uses x9-x12, x14, x16.
- 480 `c_wordconst` c_keyconst: the string value x0 (the newest thing in the heap) as a constant -> w0 which; nothing is written. c_wordconst: the same for the current word's own text.
- 487 `c_keyconst` 
- 500 `c_scan_meth` c_scan_meth: called for each word while a body is read through in advance: a name, brackets, then { is a method written short in an object, an inner function like any other. Its state is kept at 88 in the frame. Uses x9-x12.
- 556 `c_declare` c_declare: the current word as a variable of the function being translated -> w0 its number (made if new). Uses x1-x11.
- 594 `c_declref` c_declref: the current word declared where we are (a function's variable, or a global) -> w0 its reading instruction
- 608 `c_ref` c_ref: the variable the current word names, looked for in this function, then each one around it, then the globals -> w0 its reading instruction
- 656 `c_hoist` c_hoist: the declared functions waiting (from the newest back to x0) are made and stored under their names
- 678 `LEXSAVE` Looking ahead without moving: the word reader's place is kept and put back.
- 686 `LEXBACK` macro
- 695 `c_peek_each` c_peek_each: does a for's head begin (var) name in, or (var) name of -> w0 1 for in, 2 for of, 0 for neither
- 725 `c_peek_name` c_peek_name: is the word after the current one => -> flags: eq if so
- 739 `c_peek_paren` c_peek_paren: the current word is ( : is the word after its matching ) => -> flags: eq if so
- 772 `c_scan_expr` c_scan_expr: an arrow's body that is an expression starts at the current word: does it hold an inner function? If so the function being translated is marked. Nothing moves.
- 821 `c_scan_block` c_scan_block: the current word is the { of a function's body. Its words are read through once, to the matching }, to learn what the translator must know before it starts: the variables declared in it (var, let, const, and the names of functions declared at a s
- 967 `c_scan_inner` marks the function being translated as having inner functions. Uses x9, x10.
- 979 `c_function` c_function: a function, translated where it stands (jumped over when the program runs through), and its plan made a constant. w0 says which kind: 0 after the word "function" in an expression, 1 the same as a declaration (its making waits for the scope's start,
- 1186 `c_skip_default` c_skip_default: steps over a parameter's default, from its first word to the , or ) that ends it (left as the current word)
- 1212 `c_defaults` c_defaults: the parameters' defaults, translated at the body's start (when it is known where the variables live): the reader goes back to the first parameter (its place kept at x0), and for each one with a default: if it holds undefined, the default is worked 
- 1261 `c_hexv` c_string: the quoted string that is the current word, its escapes worked out -> x0 a string value
- 1272 `c_hex4` four hex digits at x3 (before x4) -> w5. Uses w6-w8, x16.
- 1284 `c_string` 
- 1470 `c_escapes` 
- 1476 `c_expr` Expressions, loosest first. Each leaves exactly one value on the machine's stack. c_expr: with commas
- 1488 `c_assign` c_assign: an assignment, or anything tighter
- 1536 `c_cond` c_cond: a ? b : c
- 1559 `c_binary` c_binary: operators between two values that bind at least as tightly as w0
- 1608 `c_unary` c_unary: operators before a value
- 1688 `c_postfix` c_postfix: x++ and x-- (the old value, as a number, is the result)
- 1760 `c_method` c_method: a call is about to be written: if what was just read is a property, the object stays under the function to be its `this` -> w0 the calling instruction to use
- 1794 `c_member` c_member: .name or [key] after a value, if that is what comes -> w0 1 if one was taken
- 1829 `c_new` c_new: new F(a, b): the function (a value and its properties, no calls), then the arguments if there are any
- 1855 `c_object` c_object: { name: value, "text": value, 3: value, [key]: value, name, name(a) { } } -> the object. The } stays the current word. Kept: 8 the name's constant, 16 and 24 the name's word, 32 its kind, 40 and 48 the word after it.
- 1924 `c_array` c_array: [a, b, c] -> the array. The ] stays the current word.
- 1970 `c_args` c_args: the arguments of a call, from the word after the ( to past the ) -> w0 how many are on the stack, or -1 if one was spread, when they are all in one array instead
- 2011 `c_template` c_template: `text ${value} text`: the pieces of text and the values between them, added together from the left. The reader gave the whole template as one word; it is sent back in to read each value. (A value is turned to text as + would, which differs from the
- 2076 `c_primary` c_primary: a number, a string, a name, a word that is a value, or an expression in brackets
- 2220 `c_var` Statements. Each leaves the machine's stack as it found it. c_var: var, let or const (the current word) and what it declares, up to but not past the end of the statement
- 2252 `c_semi` c_semi: the end of a statement: a ; or, where the language lets it be left out, a line end, a } or the end of the text
- 2263 `LOOP_IN` macro
- 2270 `LOOP_OUT` macro
- 2275 `c_stmt` c_stmt: one statement. Its frame: 8, 16, 24, 56 for places in the instructions; 32-55 a loop's record.
- 2296 `s_word` 
- 2325 `s_expr` 
- 2330 `s_var` 
- 2334 `s_if` 
- 2357 `s_while` 
- 2382 `s_do` 
- 2407 `s_for` 
- 2476 `s_each` for (name in value), for (name of value): 24 the variable, 56 which (1 in, 2 of)
- 2522 `s_return` 
- 2540 `s_break` 
- 2543 `s_continue` 
- 2555 `s_done` 

## machine.S (1087 lines)
The machine: runs the instructions the translator wrote. A stack machine: values go on a stack in the world; each instruction is one byte, some followed by a small number (low byte first). While it runs: x19 the world, x21 the next instruction, x22 the stack's top (the next free place), x23 the constants, x24 the globals, x25 steps left, x26 the stack's end.
- 88 `v_text` In the heap, an object begins with its kind: 1 a function (then: its plan, the scope it remembers), 2 a function's plan (then: where its instructions start, parameters (32 bits) and variables in all (32 bits), flags (1: its variables live in the heap because i
- 134 `s_end` 
- 137 `v_join` v_join: the two string values x0 and x1 as one string -> x0 (0 if the world is full)
- 173 `v_int32` v_int32: the number d0 as the language's 32-bit whole number (wrapping round) -> w0
- 198 `PUSH` m_run: runs until the program ends, the steps run out, or it goes wrong -> x0 0, 1 or -1
- 203 `POP` macro reg
- 206 `NEXT` macro
- 209 `m_run` 
- 230 `m_next` 
- 240 `m_pause` 
- 243 `m_halt` 
- 248 `m_leave` 
- 261 `m_deep` 
- 265 `m_full` 
- 269 `m_notfn` 
- 273 `m_wrong` 
- 276 `m_fail` 
- 286 `e_wrong_end` 
- 288 `e_notfn_end` 
- 290 `s_function_end` 
- 292 `U16` macro reg
- 295 `i_const` 
- 300 `i_undef` 
- 304 `i_null` 
- 308 `i_true` 
- 313 `i_false` 
- 317 `i_getg` 
- 323 `i_setg` 
- 329 `i_pop` 
- 332 `i_dup` 
- 336 `i_void` 
- 341 `TWO` TWO: the top two values as numbers -> d1 (the lower, left) and d0 (the top, right); the stack loses one place
- 355 `RESULT` macro
- 359 `m_two_slow` not both numbers: each is made one, by the language's rules
- 369 `i_add` 
- 403 `i_sub` 
- 407 `i_mul` 
- 411 `i_div` 
- 415 `i_mod` the remainder, exact, with the sign of the left side
- 458 `m_fmod` m_fmod: the remainder of d2 by d3 (both above zero and finite, d2 not the smaller) -> d6, exact whatever their sizes: the digits of one are taken from the other a binary place at a time. Uses x0-x6.
- 512 `i_pow` whole powers by repeated squaring; others are to come with the Math library
- 570 `PAIRMUL` PAIRMUL: the pair (\ah, \al) times the pair (\bh, \bl) -> (\ah, \al). A pair is a double and the small amount by which it misses the true value; the fused multiply-add gives a product's own miss exactly. d21 holds infinity. Uses d18-d20.
- 588 `m_powloop` the pair (d5, d16) to the whole power x0 -> the pair (d4, d17)
- 599 `i_neg` 
- 604 `i_plus` 
- 608 `i_not` 
- 613 `i_bitnot` 
- 620 `i_typeof` 
- 655 `m_bool` m_bool: the top of the stack becomes true or false by w0
- 663 `ORDER` ORDER: the top two compared: text against text by its characters, anything else as numbers. -> flags as after comparing left with right (unordered if a not-a-number is involved); the stack loses one place.
- 668 `m_order` 
- 708 `i_lt` 
- 712 `i_gt` 
- 716 `i_le` 
- 720 `i_ge` 
- 724 `i_eq` 
- 729 `i_ne` 
- 735 `i_seq` 
- 740 `i_sne` 
- 747 `BITS` BITS: the top two as 32-bit whole numbers -> w1 (left), w0 (right); the stack loses one place
- 757 `i_band` 
- 762 `i_bor` 
- 767 `i_bxor` 
- 772 `i_shl` 
- 777 `i_shr` 
- 782 `i_ushr` 
- 787 `FAR` macro reg
- 790 `i_jmp` 
- 794 `i_jf` 
- 801 `i_jt` 
- 808 `i_jfk` 
- 817 `i_jtk` 
- 826 `i_jnk` 
- 838 `i_print` a line of the values' texts, a space between
- 840 `m_print_n` 
- 872 `i_getl` 
- 877 `i_setl` 
- 883 `UPVAR` UPVAR: the place of a variable some scopes out -> x2 (its address); its number in x0
- 895 `i_getup` 
- 900 `i_setup` 
- 905 `i_closure` 
- 924 `i_callee` 
- 928 `i_call` 
- 930 `m_call_n` 
- 935 `m_call` w0 arguments from x1 on, the function under them; x11 this, x12 where the answer goes, x13 by `new`?
- 1049 `i_ret` 
- 1071 `m_table` 

## objects.S (1072 lines)
Objects, arrays and functions in the heap, and the instructions that work on them (stage 4, first part). Every one begins the same way: 0 its kind (1 function, 3 plain object, 4 array), 8 its prototype (an object value, or null), 16 where its own properties are (pairs: name, a string value; value), 24 how many (32 bits) and room for how many (32 bits). Then, a function: 32 its plan, 40 the scope it remembers, 48 the `this` it was made under (used by arrows). An array: 32 where its items are, 40 how many (32 bits) and room for how many (32 bits). An item never written reads undefined. Properties are searched in order, by text (the same string value is seen at once); shapes are to replace this
- 19 `o_keyeq` o_keyeq: are the string values x1 and x2 the same text -> flags: eq if so. Uses x3-x8.
- 43 `o_find` o_find: the object at the address x0, its own property named x1 -> x2 where its value is (an address), or 0. Uses x2-x13.
- 61 `o_get` o_get: the object value x0, its property named x1, looked for in it and then along its prototypes -> x0 (undefined if nowhere)
- 77 `o_put` o_put: the object at the address x0 gets x2 as its own property named x1 -> x0 not 0, or 0 if the world is full
- 123 `o_make` o_make: a new object of x0 bytes and the kind x1, with no prototype and nothing in it -> x0 where (0 if the world is full)
- 141 `a_set` a_set: the array at the address x0 gets x2 as its item number x1; it grows as needed -> x0 not 0, or 0 if there is no room (an item number of sixteen million or more is refused for now)
- 200 `m_keys` m_keys: the names the machine itself knows (length, prototype, constructor) are made once, in the world's head
- 213 `k_end` 
- 215 `e_noprops_end` 
- 217 `m_noprops` 
- 223 `m_fnproto` m_fnproto: the function value x0, its `prototype` property (made the first time it is asked for: an object whose `constructor` is the function) -> x0 the value, or 0 if the world is full
- 259 `m_getprop` m_getprop: the value x0, its property named x1 (a string value) -> x0. An array's and a string's length are worked out here.
- 314 `m_setprop` m_setprop: the value x0 gets x2 as its property named x1. Setting an array's length cuts it or fills it out.
- 363 `m_index` m_index: is the key x1 a whole number that can be an item's number -> w3 1 and x2 the number, or w3 0. Uses x16, x17, d0, d1.
- 374 `m_this` m_this: the `this` of the running call -> x0 (undefined outside any call)
- 381 `i_object` 
- 390 `i_array` + 16 bits: how many values on the stack become its items
- 416 `i_getp` + 16 bits: the name (a constant). object -> value
- 423 `i_setp` object, value -> value
- 432 `i_initp` object, value -> object (a literal being filled)
- 439 `i_gete` object, key -> value. i_getek: object, key -> object, value (a method about to be called)
- 440 `i_getek` 
- 491 `i_sete` object, key, value -> value. i_inite: -> object
- 492 `i_inite` 
- 525 `i_this` 
- 529 `i_swap` 
- 533 `i_rot` a, b, c -> c, a, b
- 539 `i_pick` + 8 bits: a copy of the value that many below the top
- 546 `i_dup2` 
- 551 `i_callm` + 8 bits: how many arguments; under them the function, and under it the object it is called on
- 553 `m_callm_n` 
- 559 `i_new` + 8 bits: how many arguments; under them the function. A new object is its `this`,
- 561 `m_new_n` 
- 594 `i_append` array, value -> array, the value its new last item
- 603 `i_spread` array, array or string -> array, each item of the second added to the first
- 642 `i_apply` + 8 bits: which call. The array on top is taken apart into the call's arguments
- 669 `m_plan` m_plan: the function under the arguments at x1, looked at again -> x2 it, x4 its plan, w5 parameters, w6 variables, x9 flags
- 680 `a_from` a_from: a new array of the x1 values at the address x0 -> x0 the array value, or 0 if the world is full. Uses x0-x14, x16.
- 709 `a_text` a_text: the array value x0 as text: its items' texts with commas between (undefined and null give nothing) -> x0, 0 if full. (An array that holds itself is not guarded against yet.)
- 763 `m_delprop` m_delprop: the value x0 loses its own property named x1, if it has it; the ones after it keep their order
- 786 `i_in` key, object -> is it a property of the object, or of its prototypes
- 818 `i_instof` value, function -> is the function's prototype among the value's prototypes
- 841 `i_delp` + 16 bits: the name. object -> true
- 848 `i_dele` object, key -> true (an array's item becomes undefined)
- 880 `k_add` Loops over keys and items. The loop keeps two values on the stack: an array (of the keys, or the thing looped over itself) and how far it has got. OP_KEYS and OP_ITER make the first from the value given; OP_FORNEXT takes the next item or leaves. k_add: the val
- 889 `m_keylist` m_keylist: the names a for..in loop goes through for the value x0, as an array of strings -> x0, or 0 if the world is full. An array's item numbers first, then its own properties in the order they were made, then its prototypes' (none twice). (Not right yet: w
- 975 `m_chars` m_chars: the string value x0 as an array of its characters, each a string -> x0, or 0 if the world is full (bytes for now: a character outside ASCII comes apart, until strings are kept as the language's units)
- 1027 `e_noiter_end` 
- 1029 `i_keys` value -> the array of names to loop over
- 1035 `i_iter` value -> the array to loop over: an array is itself, a string gives its characters
- 1052 `i_fornext` + 32 bits: how far to jump when there are no more. array, place -> array, place + 1, item

## entries.S (232 lines)
The entries. x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
- 2 `ENTER` The entries. x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
- 12 `LEAVE` macro
- 23 `begin` begin: makes the block a fresh world -> 1, or -1
- 29 `numtext` numtext: for the test bench: the number whose 64 bits are the argument, as text, joined to the world's printed text with a line end (the block becomes a fresh world first if it is not one yet) -> the text's length, or -1
- 54 `e_handle` e_handle: the block for the handle in the first number -> x9, or 0. Uses x10.
- 67 `e_world` e_world: the same, and it must be a world that has begun -> x9, or 0
- 81 `load` load: the text at the handle in the first number is copied into the world and translated -> 1, or -1 (see error)
- 117 `run` run: runs the loaded program for at most the argument's steps -> 0 finished, 1 out of steps (call again), -1 it went wrong
- 135 `text` text: what the program at the handle has printed since last asked, into this block from byte 64 -> how many bytes, or -1
- 161 `error` error: the last error of the world at the handle, as "message (line L, column C)", into this block from byte 64 -> how many bytes (0 if there is none), or -1
- 202 `e_put` the x1 bytes at x0 go to x13
- 209 `e_dec` the whole number w0 in decimal goes to x13. Uses x14-x17, x1.

## Instructions
HALT=0 CONST=1 UNDEF=2 NULL=3 TRUE=4 FALSE=5 GETG=6 SETG=7 POP=8 DUP=9 ADD=10 SUB=11 MUL=12 DIV=13 MOD=14 POW=15 NEG=16 PLUS=17 NOT=18 BITNOT=19 TYPEOF=20 LT=21 GT=22 LE=23 GE=24 EQ=25 NE=26 SEQ=27 SNE=28 BAND=29 BOR=30 BXOR=31 SHL=32 SHR=33 USHR=34 JMP=35 JF=36 JT=37 JFK=38 JTK=39 JNK=40 PRINT=41 VOID=42 GETL=43 SETL=44 GETUP=45 SETUP=46 CLOSURE=47 CALL=48 RET=49 CALLEE=50 OBJECT=51 ARRAY=52 GETP=53 SETP=54 GETE=55 SETE=56 INITP=57 INITE=58 GETEK=59 CALLM=60 NEW=61 THIS=62 SWAP=63 ROT=64 PICK=65 DUP2=66 IN=67 INSTOF=68 DELP=69 DELE=70 KEYS=71 ITER=72 FORNEXT=73 APPEND=74 SPREAD=75 APPLY=76 COUNT=77

## Punctuation numbers
0 `>>>=` 1 `...` 2 `===` 3 `!==` 4 `**=` 5 `<<=` 6 `>>=` 7 `>>>` 8 `&&=` 9 `||=` 10 `??=` 11 `=>` 12 `==` 13 `!=` 14 `<=` 15 `>=` 16 `&&` 17 `||` 18 `??` 19 `?.` 20 `++` 21 `--` 22 `+=` 23 `-=` 24 `*=` 25 `/=` 26 `%=` 27 `&=` 28 `|=` 29 `^=` 30 `<<` 31 `>>` 32 `**` 33 `{` 34 `}` 35 `(` 36 `)` 37 `[` 38 `]` 39 `;` 40 `,` 41 `<` 42 `>` 43 `+` 44 `-` 45 `*` 46 `/` 47 `%` 48 `&` 49 `|` 50 `^` 51 `!` 52 `~` 53 `?` 54 `:` 55 `=` 56 `.` 57 `@` 58 `#`
