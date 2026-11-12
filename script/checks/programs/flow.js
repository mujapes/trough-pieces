
var total = 0;
for (var i = 0; i < 10; i++) { for (var j = 0; j < 10; j++) { if (j > i) break; if ((i + j) % 3 == 0) continue; total += i * j; } }
console.log(total);
var n = 27, steps = 0; while (n != 1) { n = n % 2 ? 3 * n + 1 : n / 2; steps++; } console.log(steps);
var a = 0, b = 1, t; for (var k = 0; k < 80; k++) { t = a + b; a = b; b = t; } console.log(a, b);
for (;;) { steps--; if (steps < 100) break; } console.log(steps);
var c = 0; for (; c < 3;) c++; console.log(c);
var d = 5; do d--; while (d > 0) console.log(d);
do { d++; if (d < 3) continue; break; } while (true); console.log(d);
if (d) console.log("one"); else console.log("two");
if (!d) console.log("one"); else if (d == 3) console.log("three"); else console.log("two");
if (0) ; else { { console.log("nested"); } }
var p = 1, primes = "";
while (p++ < 60) { var q = 2, ok = true; while (q * q <= p) { if (p % q == 0) { ok = false; break; } q++; } if (ok) primes += p + " "; }
console.log(primes);
var x = 1, y = 2, z
z = x
+ y
console.log(z)
x
++
y
console.log(x, y)
var s = ""; for (var m = 0, w = 10; m < w; m += 3, w--) s += m + ":" + w + " "; console.log(s);
var u; console.log(u, typeof u, typeof nothere, u = 3, u, (u = 4, u + 1));
var e = 2; e **= 3; e += "px"; console.log(e); e = 7; e %= 4; e |= 8; e &= 13; e ^= 1; e >>= 1; e >>>= 0; e <<= 3; e /= 5; e -= .5; console.log(e);
var f = null; f ??= 5; f ||= 6; f &&= 7; console.log(f); var g = 0; g &&= 9; g ||= 8; g ??= 1; console.log(g);
console.log(1 + 2 * 3 - 4 / 2, (1 + 2) * 3, 2 ** 3 ** 2, 1 < 2 == true, 1 + "2" + 3, 1 + 2 + "3", "5" * "4", "5" - 2, 8 >> 1 + 1, 1 | 2 & 3 ^ 4, !1 + 1);
