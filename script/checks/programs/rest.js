function r(a, ...more) { return a + "|" + more.length + "|" + more; }
console.log(r(), r(1), r(1, 2), r(1, 2, 3, "x"), ((...all) => all.length)(5, 6, 7), "" + [1, [2, 3], null, undefined, "s", {}]);
function args() { var n = arguments.length, s = 0; for (var i = 0; i < n; i++) s += arguments[i]; return s; }
console.log(args(), args(1), args(1, 2, 3, 4), (function (a) { return arguments.length + ":" + a + ":" + arguments[2]; })(7, 8, 9));
function both(x = 1, ...ys) { var f = () => ys.length + x; return f() + arguments.length * 100; } console.log(both(), both(undefined, 1, 2));
var o = { a: 1, b: undefined, c: 3 }, arr = [5, 6, 7];
console.log("a" in o, "b" in o, "z" in o, 1 in arr, 3 in arr, "a" + 1 in o, !("a" in o));
console.log(delete o.a, "a" in o, o.a, delete o["c"], "c" in o, delete o.never, delete arr[1], arr[1], arr.length, "" + arr);
o.c = 9; o.a = 8; var keys = { one: 1, two: 2, three: 3 }; delete keys.two; keys.two = 22; console.log(o.c, o.a, keys.one + keys.two + keys.three);
function A() {} function B() {} var a = new A(); B.prototype = new A(); var b = new B();
console.log(a instanceof A, a instanceof B, b instanceof A, b instanceof B, 5 instanceof A, {} instanceof A, 1 < 2 instanceof A);
