// stage 5: throw, try, catch, finally, the error classes
try { throw 1; } catch (e) { console.log("caught", e); }
try { console.log("a"); } finally { console.log("fin"); }
function f(n) { if (n > 2) throw new Error("too big " + n); return n; }
try { console.log(f(1)); console.log(f(5)); console.log("no"); } catch (e) { console.log(e.name, e.message, e instanceof Error, e.toString()); }
function g() { try { return "from try"; } finally { console.log("g finally"); } }
console.log(g());
function h() { try { throw "x"; } catch (e) { return "caught " + e; } finally { console.log("h finally"); } }
console.log(h());
function k() { try { return 1; } finally { return 2; } }
console.log(k());
function deep(n) { if (n == 0) throw new RangeError("bottom"); return deep(n - 1) + 1; }
try { deep(50); } catch (e) { console.log(e.name, e.message, e instanceof RangeError, e instanceof Error, e instanceof TypeError); }
var log = "";
for (var i = 0; i < 5; i++) {
  try { if (i == 1) continue; if (i == 3) break; log += "b" + i; } finally { log += "f" + i; }
}
console.log(log);
try { try { throw new TypeError("inner"); } finally { console.log("inner finally"); } } catch (e) { console.log("outer", e.message); }
try { try { throw 1; } catch (e) { throw e + 1; } finally { console.log("f2"); } } catch (e) { console.log("rethrown", e); }
try { null.x; } catch (e) { console.log(e instanceof TypeError, e.name); }
try { var u; u(); } catch (e) { console.log(e instanceof TypeError); }
try { (function r() { r(); })(); } catch (e) { console.log(e instanceof RangeError); }
function m() { for (var x of [1, 2, 3]) { try { if (x == 2) return "ret " + x; } finally { console.log("m fin", x); } } }
console.log(m());
class MyErr extends Error { constructor(m, code) { super(m); this.code = code; } }
MyErr.prototype.name = "MyErr";
try { throw new MyErr("mine", 7); } catch (e) { console.log(e.name, e.message, e.code, e instanceof MyErr, e instanceof Error, "" + e.toString()); }
function n2() { var s = ""; for (var j = 0; j < 3; j++) { try { throw j; } catch (e) { s += e; continue; } finally { s += "!"; } } return s; }
console.log(n2());
var o = { get bad() { throw new Error("getter"); } };
try { o.bad; } catch (e) { console.log(e.message); }
function w() { try { throw 1; } catch { return "no binding"; } }
console.log(w());
function outer() { try { return inner(); } catch (e) { return "outer caught " + e.message; } }
function inner() { try { throw new Error("deep"); } finally { console.log("inner cleanup"); } }
console.log(outer());
console.log(new Error("plain").message, new Error().message === "", new TypeError("t").name);
