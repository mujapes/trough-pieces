let hits = 0, sink = 0;
let obj = {
  _a: 5, get a() { hits++; return this._a * 2; }, set a(v) { this._a = v + 1; },
  get ro() { hits++; return 99; }, set wo(v) { sink = v * 3; }
};
console.log(obj.a, obj.ro, obj.wo, sink, hits, "a" in obj, "ro" in obj, "wo" in obj, "x" in obj);
obj.a = 10; obj.ro = 123; obj.wo = 7;
console.log(obj.a, obj._a, obj.ro, obj.wo, sink, hits);
function Box(v) { this.v = v; }
Box.prototype = { v: 2, get dbl() { hits++; return this.v * 2; } };
let b1 = new Box(6), b2 = new Box(15), p1 = { get: 1, set: 2 }, p2 = { get() { return 3; }, set(x) { return x + 4; } };
console.log(Box.prototype.dbl, b1.dbl, b2.dbl, "dbl" in b1, hits, p1.get, p1.set, p2.get(), p2.set(5));
