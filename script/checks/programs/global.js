globalThis.b = 2; console.log(b + 1, globalThis.b, typeof globalThis.nothing, 'b' in globalThis, globalThis.globalThis === globalThis);
function late() { return later1 + 1 } globalThis.later1 = 41; console.log(late());
b = 7; console.log(globalThis.b); globalThis['x-y'] = 5; console.log(globalThis['x-y']);
var f = console.log; f('via value', 1, 'two'); console.log(typeof console, typeof console.log, typeof console.warn);
try { nope } catch (e) { console.log(e.message) }
