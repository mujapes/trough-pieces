let shadow = ""; { let a = 1; const b = 2; { let a = 10; const b = 20; { let a = 100; const b = 200; shadow += "" + [a, b] + " "; } shadow += "" + [a, b] + " "; } shadow += "" + [a, b]; } console.log(shadow);
{ let fL = [], fV = []; for (let i = 0; i < 3; i++) fL[i] = () => i; for (var v = 0; v < 3; v++) fV[v] = () => v; console.log("" + [fL[0](), fL[1](), fL[2]()], "" + [fV[0](), fV[1](), fV[2]()]); }
{ let fOf = [], fIn = [], iOf = 0, iIn = 0; for (let x of [10, 20]) { fOf[iOf++] = () => x; } for (let k in {a: 1, b: 2}) { fIn[iIn++] = () => k; } console.log("" + [fOf[0](), fOf[1]()], "" + [fIn[0](), fIn[1]()]); }
try { let x = y; let y = 1; } catch (e) { console.log(e instanceof ReferenceError, e.name, typeof e.message); }
try { const c = 10; c = 20; } catch (e) { console.log(e instanceof TypeError, e.name, typeof e.message); }
{ console.log(typeof f1, f1(), f2()); function f1() { return "b-fn1"; } function f2() { return "b-fn2"; } }
function testSwitch(v) {
  let r = "";
  switch (v) {
    case 1: r += "one,";
    case "str": { let s = "braced"; r += s + ","; break; }
    default: r += "def,";
    case 2: r += "two"; break;
  }
  return r;
}
console.log(testSwitch(1), testSwitch("str"), testSwitch(99), testSwitch(2));
{ let b = "", c = ""; oB: for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) { if (i === 1 && j === 1) break oB; b += "" + i + j + " "; } oC: for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) { if (j === 1) continue oC; c += "" + i + j + " "; } console.log(b, c); }
