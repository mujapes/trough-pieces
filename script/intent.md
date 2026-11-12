# script

## What this is for
Pages are programs as much as documents: without running their scripts most modern sites show nothing. This is
Trough's own engine for the language of the web (JavaScript, ECMAScript), hand-written in machine code like every
other piece. The user's instruction (2026-11-12): build the full language, not a token subset. It is built in
stages; each stage runs real programs and is compared, program by program, with reference engines on the bench
(`qjs`, `node`), which are never a fallback.

## Shape
- **No memory of its own.** Everything a running program has lives in one block the host owns, the *world*
  (kind 6): a 256-byte head, then a heap that only this piece reads. The host says how big; a program that
  fills it is stopped with an error, not the app.
- **Values** are 64 bits. A value that is not a NaN is a number (IEEE double). The rest are packed into the
  NaN space: top 16 bits `0xfff8`+tag, low 48 bits a payload. Tags: 1 undefined, 2 null, 3 boolean (payload
  0 or 1), 4 string, 5 object (function, array and plain object are objects), 6 a 32-bit integer kept exact
  for loops and indexes (reads as a number everywhere). Payloads of 4 and 5 are offsets into the world's heap,
  never addresses: a world can be moved, saved, or handed to a new build of this piece (hot reload).
- **Source → bytecode → run.** One pass over the text (precedence climbing) writes bytecode for a stack machine
  into the world; nothing is kept as a tree. Functions close over their surroundings through chained scope
  objects in the heap. Property lookup goes through shapes (a per-object list of names in insertion order,
  shared when equal) so it stays quick.
- **Strings** are UTF-16 code units, as the language requires, with a flag for those that are all below 256
  so they take one byte a unit.
- **Reclaiming memory**: mark from the roots (stack, globals, scopes), then compact, done between tasks, not
  inside one; offsets make moving safe. Until that stage exists a world simply fills.
- **Outside world** (the document, timers, the console, the network) is not in this piece: the program calls
  numbered *host functions*; the piece returns to its caller saying "host function N wanted, arguments are
  here", and is entered again with the answer. So it never calls out, can be stopped at any call, and the
  document can be a piece of its own (`dom`, to come).

## Entries (as they come into being)
- **begin**(world) → makes a fresh world of the block (1), or -1 if it is too small (under 1 MB) or not kind 6.
- **load**(world, numbers: source handle) → compiles the text as a script into the world. 1, or -1 with the
  error (message, line, column) left in the world for **error** to read.
- **run**(world, numbers: -; argument: how many steps at most) → runs. 0 finished; 1 out of steps (call again);
  2 a host function is wanted (see **wanted**, answer with **answer**); -1 the program threw and nothing
  caught it (see **error**).
- **wanted**(block, numbers: world handle) → which host function and its arguments, as text the host can read.
- **answer**(world, numbers: value handle) → gives the host function's result back.
- **error**(block, numbers: world handle) → the message, line and column of the last error, as text.
- **text**(block, numbers: world handle, which) → output the program has produced (console) since last asked.

## Stages
1. **Words**: the text taken apart into names, numbers, strings, punctuation, with the language's rules for
   where a statement ends when the `;` is left out, and which `/` starts a pattern. (lexer)
2. **Arithmetic and names**: numbers, strings, booleans, `var`/`let`/`const`, every operator with its
   precedence and conversions (`+` on strings, `==` against `===`, `typeof`), `if`, loops, `console.log`.
   Number to text and text to number exactly as the language says (shortest text that reads back the same).
3. **Functions**: declarations, expressions, arrows, closures, `this`, `arguments`, default and rest
   parameters, `return`; recursion to a stated depth.
4. **Objects and arrays**: literals, property access, shapes, prototypes, `new`, classes, getters and setters,
   spread and destructuring, `for..in`, `for..of`, iterators, template strings.
5. **Errors**: `throw`, `try`/`catch`/`finally`, the error types, messages with line numbers.
6. **The library**: Object, Array, String, Number, Math, JSON, Map, Set, Date, RegExp (its own small engine),
   Promise and the job queue, `async`/`await`, generators, Symbol, typed arrays as needed by real pages.
7. **Reclaiming memory.**
8. **The document**: a `dom` piece (the page as a tree, built by the page piece's reader), host functions that
   let a program read and change it, events, timers, fetch; layout done again when the tree changes.
9. **Real pages**: modules, the long tail the test suite finds (test262 on the bench, a share at a time).

## How it is checked
Each stage has a folder of small programs under `script/checks/`; each is run by the piece and by the reference
engines and the outputs must be the same text. The recorded checks (the piece's own judge for promotion) are
made from the same programs. A program the piece gets wrong is added before it is fixed.

## Not decided yet
Whether hot paths get machine code of their own made at run time (a compiler inside the engine): the code
stream and the writable-and-runnable memory this phone allows make it possible; the interpreter comes first.
