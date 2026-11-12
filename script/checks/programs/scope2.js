// block scope: the corners (slots inside functions, scopes with closures, leaving blocks early)
function slots(n) { let a = 1; { let a = 2; { let a = 3; n += a; } n += a; } for (let i = 0; i < 3; i++) { let a = i * 10; n += a; } return n + a; }
console.log(slots(0));
function mk() { var fs = []; for (let i = 0; i < 3; i++) { let j = i * 2; fs[i] = function () { return i + ":" + j; }; } return fs; }
var fs = mk(); console.log(fs[0](), fs[1](), fs[2]());
function early() { var fs = [], out = ""; for (let i = 0; i < 5; i++) { let k = i; fs[fs.length] = () => k; if (i == 1) continue; if (i == 3) break; out += i; } return out + "|" + fs[0]() + fs[1]() + fs[3](); }
console.log(early());
function fin() { let log = ""; var g; for (let i = 0; i < 2; i++) { try { let t = "t" + i; g = () => t; { let u = 1; if (i == 0) continue; return log + g() + u; } } finally { let f = "f" + i; log += (() => f)(); } } }
console.log(fin());
function inc() { for (let i = 0; i < 3; i++) { var f = () => i; i++; } return f(); }
console.log(inc());
function cst() { const k = 1; try { k = 2; } catch (e) { return e.name + " " + k; } }
console.log(cst());
function cst2() { const o = { n: 1 }; o.n += 1; try { { const z = 5; z++; } } catch (e) { return e instanceof TypeError ? "t" + o.n : "no"; } }
console.log(cst2());
let top = "T"; { let top = "inner"; var seen = () => top; } console.log(top, seen());
var acc = []; for (const x of [1, 2, 3]) { acc[acc.length] = () => x * 2; } console.log(acc[0](), acc[2]());
outer: for (let a = 0; a < 3; a++) { for (let b = 0; b < 3; b++) { let h = () => a * 10 + b; if (b == 1) continue outer; if (a == 2) break outer; console.log(h()); } }
function blockfn() { let r = ""; { let v = "v"; r += g(); function g() { return v + "g"; } } { let v = "w"; r += h(); function h() { return v + "h"; } } return r; }
console.log(blockfn());
function sw(x) { switch (x) { case 1: { let m = "one"; return () => m; } default: { let m = "other"; return () => m; } } }
console.log(sw(1)(), sw(2)());
function deep() { let s = ""; for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) { let f = () => "" + i + j; s += f() + " "; } return s; }
console.log(deep());
if (true) { let q = 1; if (q) { let q = 2; console.log(q); } console.log(q); }
console.log(typeof q, typeof top);
