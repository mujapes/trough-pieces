// pattern literals and the text functions that take patterns
function show(l, v) { console.log(l, JSON.stringify(v)); }
var s = 'The quick brown fox, the lazy dog; 12 apples and 345 pears.';
show('lit', [/qu(i)ck/.test(s), /\d+/g.flags, /a\/b[/]c/.source, (/x/i).ignoreCase, 8 / 2 / 2]);
var a = 6, g = 2; show('div', a / g / 3); show('div2', [a /g/ 1, a++ / 2, (a) / 3]);
show('match', s.match(/(\w+) (\w+)/)); show('matchi', s.match(/(\w+) (\w+)/).index);
show('matchg', s.match(/\d+/g)); show('matchn', s.match(/zzz/g)); show('match0', 'abc'.match(/x*/g));
show('matchs', 'a.b'.match('.'));
var out = []; for (var m of s.matchAll(/(\w)(\w*)x/g)) out.push(m[0], m[1], m.index); show('matchAll', out);
show('spread', [...'a1b22c333'.matchAll(/\d+/g)].map(function (m) { return m[0] + '@' + m.index; }));
show('search', [s.search(/fox/), s.search(/cat/), s.search('lazy'), 'x'.search(/(?:)/)]);
show('rep1', s.replace(/the/i, 'A')); show('repg', s.replace(/the/gi, '[$&]'));
show('rep$', 'john smith'.replace(/(\w+)\s(\w+)/, '$2, $1 $$ $` $\' $3 $0 $10 $01'));
show('repf', s.replace(/(\d)(\d*)/g, function (m, a, b, i, t) { return '<' + a + '|' + b + '|' + i + '|' + (t === s) + '>'; }));
show('reps', 'aaa'.replace('a', 'b$&$&')); show('repe', 'abc'.replace(/x*/g, '-')); show('repu', 'ab'.replace(/(a)|(b)/g, function (m, x, y) { return '[' + x + ',' + y + ']'; }));
show('repAll', ['a-b-c'.replaceAll('-', '+'), 'abc'.replaceAll('', '.'), 'a1b2'.replaceAll(/\d/g, function (d) { return d * 2; })]);
show('split', ['a1b22c'.split(/\d+/), 'a, b ,c'.split(/\s*,\s*/), 'abc'.split(/(?:)/), 'a1b2c'.split(/(\d)/), 'a1b2c3'.split(/\d/, 2), ''.split(/x/), ''.split(/x*/), 'abc'.split(/(b)?/), 'a,b,c'.split(',', 2)]);
var r = /o/g; r.lastIndex = 30; show('last', [s.replace(r, '0').length, r.lastIndex, s.match(r).length]);
var y = /fo/y; y.lastIndex = 16; show('sticky', [y.test(s), y.lastIndex, s.replace(y, 'X') === s]);
try { 'a'.matchAll(/a/); } catch (e) { show('err', e instanceof TypeError); }
show('trim', '  x  y '.replace(/^\s+|\s+$/g, '').split(/\s+/));
show('camel', 'background-color-top'.replace(/-(\w)/g, function (m, c) { return c.toUpperCase(); }));
show('tmpl', 'Hi {name}, {n} new'.replace(/\{(\w+)\}/g, function (m, k) { return { name: 'Ann', n: 3 }[k]; }));
