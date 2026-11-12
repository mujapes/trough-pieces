function f(a, b = 2, c = a + b) { return a + "," + b + "," + c; }
console.log(f(1), f(1, 5), f(1, undefined, 9), f(1, null), f());
var g = (x = 3, y = x * 2) => x + y; console.log(g(), g(1), g(1, 1));
var h = (n = 4) => { var t = n; return () => t * n; }; console.log(h()(), h(3)());
var out = 10; function k(p = out, q = (z => z + p)(1), r = (2, 3)) { var out = 99; return p + q + r; }
console.log(k(), k(1), k(1, 2, 0));
var calls = 0; function side(a = ++calls) { return a; } side(5); side(); side(); console.log(calls, side(undefined));
