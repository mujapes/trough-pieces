try { throw "str"; } catch (e) { try { throw 42; } catch (n) { console.log(e, n); } }
try { throw {code: 1}; } catch ({code}) { console.log(code); }
try { throw "nobind"; } catch { console.log("caught-nobind"); }
console.log((() => { let a = 0; try { a = 1; } finally { a = 2; } return a; })(), (() => { let b = 0; try { try { throw 1; } finally { b = 2; } } catch {} return b; })());
console.log((() => { let k = 0; function f() { try { return 10; } finally { k = 20; } } return "" + [f(), k]; })(), (() => { function g() { try { return 1; } finally { return 2; } } return g(); })());
console.log((() => { let x = 0; for (let i = 0; i < 2; i++) { try { break; } finally { x += 1; } } return x; })(), (() => { let y = 0; for (let i = 0; i < 2; i++) { try { continue; } finally { y += 1; } } return y; })());
console.log((() => { let s = ""; try { try { throw "in"; } catch (e) { s += e; throw "re"; } finally { s += "-fin"; } } catch (e) { s += "-" + e; } return s; })());
console.log((() => { let trace = ""; function f1() { f2(); } function f2() { try { f3(); } finally { trace += "f2-fin "; } } function f3() { throw "unwind"; } try { f1(); } catch (e) { trace += e; } return trace; })());
try { (undefined)(); } catch (e) { console.log(e instanceof TypeError, e.name, typeof e.message); }
try { null.p; } catch (e) { console.log(e instanceof TypeError, e.name, typeof e.message); }
try { undeclaredVar; } catch (e) { console.log(e instanceof ReferenceError, e.name, typeof e.message); }
{ const err = new Error("x"); console.log(err.name, err.message); }
{ const te = new TypeError("y"); console.log(te instanceof Error, te instanceof TypeError); }
class CustomError extends Error {
  constructor(msg, code) { super(msg); this.code = code; }
}
{ const ce = new CustomError("err", 404); console.log(ce instanceof Error, ce instanceof CustomError, ce.code); }
