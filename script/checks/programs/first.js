console.log(1 + 2);
var a = 5, b = "x";
console.log(a * 2, b + a, typeof a, typeof b, a > 3 ? "big" : "small");
for (var i = 0; i < 5; i++) { if (i == 2) continue; if (i == 4) break; console.log(i); }
var s = ""; var n = 0; while (n < 3) { s += n; n++; } console.log(s);
do { n--; } while (n > 0); console.log(n, 'it\'s', "é\x41\n\ttab");
console.log(1/3, 0.1+0.2, 1/-0, 1e21, 2**10, 7 % 3, -7 % 3, 5 / 0, NaN, undefined, null, true && "y", null ?? "d", 0 || "z");
let x = 10; x -= 3; x *= 2; x <<= 1; console.log(x, x++, ++x, x--, x, ~x, !x, 1 < 2, "a" < "b", 1 == "1", 1 === "1", null == undefined);
