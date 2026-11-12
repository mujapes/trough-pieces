// script, written by hand (ARM64): Trough's own JavaScript engine. The meaning and the plan are script/intent.md.
// The parts, each a file: the world (memory), the words (stage 1), values and their conversions, the translator from words to
// instructions, the machine that runs the instructions, and the entries. Calls nothing: the outside is reached by returning.
    .text
    .global begin
    .global tokens
    .global numtext
    .global load
    .global run
    .global text
    .global error
    .include "script/world.S"
    .include "script/lex.S"
    .include "script/tokens.S"
    .include "script/values.S"
    .include "script/strings.S"
    .include "script/num.S"
    .include "script/compile.S"
    .include "script/machine.S"
    .include "script/objects.S"
    .include "script/lib.S"
    .include "script/math.S"
    .include "script/regex.S"
    .include "script/json.S"
    .include "script/entries.S"
