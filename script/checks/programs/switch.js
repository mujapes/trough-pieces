// switch, labelled break and continue
function sw(v) {
  var r = "";
  switch (v) {
    case 1: r += "one,";
    case "str": { r += "braced,"; break; }
    default: r += "def,";
    case 2: r += "two"; break;
    case 3: return "three!";
  }
  return r;
}
console.log(sw(1), sw("str"), sw(99), sw(2), sw(3), sw("1"));
function none(v) { switch (v) { case 1: return "a"; } return "none"; }
console.log(none(1), none(2));
switch (3) { }
var out = "";
for (var i = 0; i < 6; i++) {
  switch (i % 3) { case 0: continue; case 1: out += "x" + i; break; default: out += "y" + i; }
  out += ";";
}
console.log(out);
var b = "", c = "";
oB: for (var i = 0; i < 3; i++) for (var j = 0; j < 3; j++) { if (i === 1 && j === 1) break oB; b += "" + i + j + " "; }
oC: for (var i = 0; i < 3; i++) for (var j = 0; j < 3; j++) { if (j === 1) continue oC; c += "" + i + j + " "; }
console.log(b, c);
var d = "";
outer: for (var x of [1, 2, 3]) { for (var y of "ab") { for (var k in { p: 1, q: 2 }) { if (x == 2) continue outer; if (x == 3 && y == "b") break outer; d += x + y + k + " "; } } }
console.log(d);
function lab() { var s = ""; a: while (true) { try { for (var q of [1, 2]) { switch (q) { case 2: break a; } s += q; } } finally { s += "F"; } } return s; }
console.log(lab());
var e = ""; w: do { e += "1"; switch (1) { case 1: try { continue w; } finally { e += "f"; } } e += "no"; } while (false);
console.log(e);
