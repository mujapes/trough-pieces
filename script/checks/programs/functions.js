console.log(early(3), typeof early);
function early(n) { return n * 2; }
function fib(n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
console.log(fib(20));
function counter() { var n = 0; return function () { n++; return n; }; }
var c1 = counter(), c2 = counter(); c1(); c1();
console.log(c1(), c2());
var add = (a, b) => a + b, sq = x => x * x, k = () => 7, blk = (a) => { var t = a + 1; return t * 2; };
console.log(add(2, 3), sq(9), k(), blk(4), add("a"), sq(), ((x, y) => x - y)(10, 4, 99));
var curry = a => b => c => a + b + c; console.log(curry(1)(2)(3));
function isEven(n) { return n == 0 ? true : isOdd(n - 1); } function isOdd(n) { return n == 0 ? false : isEven(n - 1); }
console.log(isEven(10), isOdd(7), isEven(7));
var fact = function f(n) { return n <= 1 ? 1 : n * f(n - 1); }; console.log(fact(10), typeof f);
function outer() { var a = 1; function mid() { var b = 2; function inner() { return a + b + g; } a += 10; return inner; } var r = mid(); a += 100; return r(); }
var g = 1000; console.log(outer());
function noret() { var x = 5; } function early2(x) { if (x) return "yes"; return
"no"; }
console.log(noret(), early2(1), early2(0));
function loop(n) { var s = 0; for (var i = 0; i < n; i++) { if (i % 2) continue; s += i; } return s; } console.log(loop(100));
function uses() { return later + inner2(); function inner2() { return v2; } var later = 1, v2 = 5; } console.log(uses());
var apply = (f, x) => f(f(x)); console.log(apply(sq, 3), apply(x => x + "!", "hi"));
function shadow(g) { var k = g + 1; return k; } console.log(shadow(1), g, k());
var total = 0; function bump() { total += 1; } for (var i = 0; i < 20000; i++) bump(); console.log(total);
function make(n) { return () => n; } var fs1 = make(1), fs2 = make(2); console.log(fs1() + fs2());
