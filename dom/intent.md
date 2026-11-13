# Dom: the page as a tree

## What this is for
What a script means by `document`: the page's elements, text and attributes as a tree that can be searched and changed.
The script engine reaches it through its host (`__host('d' + request)`); the host passes the request through unchanged.
The picture is drawn from the tree written back out as text (request `h1`) and given to `page render`. Later the page
piece can walk the records directly; the layout below is fixed for that.

## The tree is one block (kind 9), so a reload carries it over whole
- Bytes 64, 68, 72 (32-bit): how many records, where the kept text begins, the script now running.
- Records of 48 bytes from byte 96, numbered from 0 (0 is nobody, 1 is the document): kind (1 element, 2 attribute,
  3 text, 8 comment, 9 document), parent, first child, last child, previous, next, name (offset, length), text (offset,
  length), first attribute. An attribute is a record too: name, text (its value), next.
- Names are kept in small letters; text is kept decoded. Kept bytes grow down from the block's end, records up; when
  they would meet the answer is -2 and nothing is half done that matters (a record or some bytes may be wasted).
- Nothing is given back yet: removed nodes and replaced text stay in the block.

## Entries (x0 the tree block; numbers are handles)
- **begin**(tree) -> 0: an empty document. -1 if the block is not kind 9 or is under 64 kB or over 2 GB.
- **ask**(tree, numbers: request handle, answer handle) -> the answer's length (written from byte 64 of the answer
  block), -1 for a request that makes no sense (no such node, a child put under itself), -2 for no room.

## Requests: one letter, a node number, one space, then the rest
`k` kind. `n` name (`#text`, `#comment`, `#document`). `p f l N P` parent, first, last, next, previous (0: none).
`L` child numbers, `E` only the element children, separated by spaces. `g12 name` -> `0` (not there) or `1` + value.
`s12 name value`, `u12 name`. `t` text of everything inside; `T12 text` replaces the children by that text (for a text
node: its own text). `h` what is inside as HTML, `o` the node too; `H12 html` replaces the children by the html read.
`c tag`, `x text` -> a new loose node's number. `a12 34` puts 34 last under 12 (taking it from where it was); `b12 34 56`
puts 34 before 56. `r12` takes 12 out. `i name` -> the first element in the document with that id (0: none).
`q12 sel` -> the numbers of the elements under 12, in page order, where sel is `tag`, `#id`, `.class` or `*` (richer
selectors are taken apart in the language: `document.js`). `C12` says which script is running, `S` asks; `w html` puts
the html read just before that script (document.write).

## Reading HTML
Text, comments, elements with attributes (double, single or no quotes), character references (`&amp; &lt; &gt; &quot;
&apos; &nbsp; &#n; &#xh;`; others stay as written). No children: area base br col embed hr img input link meta param
source track wbr. Kept as written up to their own closing tag: script, style (raw), title, textarea (decoded). A second
li, p, option, tr, td, th, dt, dd straight inside the first ends the first. A closing tag ends the nearest open element
of that name, or is dropped. `<!...>` and `<?...>` are dropped. Not made: the other implied endings and the implied
html, head, body.

## Checks
`checks/t.c` (a bench driver: one request a line) with `checks/t.txt` and its expected answers `t.out`. There is no
reference.c: the expected answers were written by hand from what a browser gives.
