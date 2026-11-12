class Base {
  constructor(v = 10) { this.v = v; }
  inc(d = 1) { return this.v + d; }
  twice() { return this.inc(this.v); }
  static tag() { return "B"; }
  static get kind() { return "base-" + this.tag(); }
}
class Mid extends Base {}
class Sub extends Mid {
  constructor(a, b) { super(a + b); this.b = b; }
  inc(d = 2) { return super.inc(d) * 10 + this.b; }
  ["a" + 1]([x, y], {z = 3}, ...r) { return x + y + z + r.length + this.v; }
  get val() { return this.v * 2; }
  set val(n) { this.v = n + 1; }
}
class Plain { ping() { return 42; } }
let Expr = class { constructor(n) { this.n = n * 2; } };
function make(C, x) { return new C(x); }
let b = new Base(), m = new Mid(7), s = new Sub(3, 4), p = new Plain(), e = new Expr(6);
console.log(b.v, b.inc(), b.twice(), Base.tag(), Base.kind, Sub.tag(), Sub.kind, p.ping());
console.log(m.v, m.inc(5), s.v, s.b, s.inc(), s.inc(5), s.a1([1, 2], {}, 8, 9));
s.val = 20;
console.log(s.val, s.v, typeof Base, typeof Expr, e.n, make(Expr, 9).n, make(class { constructor(x) { this.x = x + 1; } }, 4).x);
console.log(s instanceof Sub, s instanceof Mid, s instanceof Base, m instanceof Base, m instanceof Sub, p instanceof Base);
