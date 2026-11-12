var o = { a: 1, "b c": 2, 3: "three", [1 + 1]: "two", nested: { deep: [10, 20, 30] } };
console.log(o.a, o["b c"], o[3], o["3"], o[2], o.nested.deep[1], o.missing, typeof o, typeof o.nested.deep);
o.a += 5; o.z = o.a * 2; o["k" + 1] = "k1"; o.a++; ++o.a; o.nested.deep[1] -= 1; o.nested.deep[2]++;
console.log(o.a, o.z, o.k1, o.nested.deep[1], o.nested.deep[2], o.a--, o.a);
var arr = [1, "two", [3, 4], {five: 5}], n = arr.length;
arr[arr.length] = 6; arr[7] = "far"; console.log(n, arr.length, arr[1], arr[2][1], arr[3].five, arr[5], arr[7], arr[99]);
arr.length = 2; console.log(arr.length, arr[1], arr[2]); var e = []; console.log(e.length, e[0], [].length);
var sum = 0; for (var i = 0; i < 1000; i++) e[i] = i * 2; for (i = 0; i < e.length; i++) sum += e[i]; console.log(sum, e.length);
var s = "hello"; console.log(s.length, s[0], s[4], s[5], "abc"[1], s.nothing);
var x = 5, y = "why", short = { x, y, m(k) { return this.x + k; }, f: function () { return this.y; }, arrow: () => typeof this };
console.log(short.x, short.y, short.m(10), short.f(), short["m"](1));
function Point(px, py) { this.x = px; this.y = py; }
Point.prototype.len2 = function () { return this.x * this.x + this.y * this.y; };
Point.prototype.kind = "point";
var p = new Point(3, 4), q = new Point(1, 1); q.kind = "mine";
console.log(p.x, p.y, p.len2(), q.len2(), p.kind, q.kind, p.constructor === Point, typeof Point.prototype);
function Maker() { this.v = 1; return { v: 2 }; } function Plain() { this.v = 1; return 7; }
console.log(new Maker().v, new Plain().v);
function Counter() { this.n = 0; this.inc = () => { this.n++; return this; }; }
var c = new Counter(); c.inc().inc(); var loose = c.inc; loose(); console.log(c.n);
function outer() { var hidden = 40; return { get2() { return hidden + 2; }, set(v) { hidden = v; } }; }
var ob = outer(); ob.set(5); console.log(ob.get2());
var a1 = [1, 2], a2 = a1; a2[0] = 9; console.log(a1[0], a1 === a2, [] === [], o === o, {} == {});
var grid = [[1, 2, 3], [4, 5, 6]]; grid[1][2] = grid[0][0] + grid[1][1]; console.log(grid[1][2], grid.length, grid[0].length);
var list = null; for (i = 0; i < 5; i++) list = { v: i, next: list }; var t = 0; while (list) { t = t * 10 + list.v; list = list.next; } console.log(t);
var fns = [function () { return 1; }, () => 2]; console.log(fns[0]() + fns[1](), o.a = 3, o.a, o[2] = o[3]);
