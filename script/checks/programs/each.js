var o = { a: 1, b: 2, c: 3 }, s = "";
for (var k in o) s += k + "=" + o[k] + ";"; console.log(s);
var arr = [10, 20, 30], t = 0; arr.extra = "x"; s = "";
for (var i in arr) s += i + ":" + typeof i + " "; for (const v of arr) t += v; console.log(s, t);
function P() { this.own = 1; } P.prototype.shared = 2; P.prototype.own = 0; s = "";
for (k in new P()) s += k + " "; console.log(s);
s = ""; for (var ch of "hello") s = ch + s; console.log(s.length, "" + (function () { var out = []; for (let x of [1, 2, 3, 4, 5, 6]) { if (x == 2) continue; if (x == 5) break; out[out.length] = x * x; } return out; })());
function find(list, want) { for (var item of list) { for (var key in item) if (item[key] === want) return key; } return "none"; }
console.log(find([{ p: 1 }, { q: 2, r: 3 }], 3), find([], 1), find([{ z: 0 }], 9));
var grow = [1, 2, 3], n = 0; for (var g of grow) { if (grow.length < 6) grow[grow.length] = g; n++; } console.log(n, "" + grow);
for (k in null) console.log("never"); for (k in undefined) console.log("never"); for (k in 5) console.log("never"); for (k of []) console.log("never");
var cnt = 0; for (var a of [1, 2]) for (var b in { x: 1, y: 2, z: 3 }) cnt++; console.log(cnt, a, b);
