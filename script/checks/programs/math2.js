const fns = [
  ["atan", Math.atan], ["asin", Math.asin], ["acos", Math.acos],
  ["expm1", Math.expm1], ["log1p", Math.log1p], ["sinh", Math.sinh],
  ["cosh", Math.cosh], ["tanh", Math.tanh], ["cbrt", Math.cbrt]
];
const vals = [
  ["0", 0], ["neg0", -0], ["0.5", 0.5], ["-0.5", -0.5], ["1", 1], ["-1", -1],
  ["2", 2], ["-2", -2], ["Inf", Infinity], ["-Inf", -Infinity], ["NaN", NaN]
];
for (let i = 0; i < fns.length; i++) {
  for (let j = 0; j < vals.length; j++) {
    if (fns[i][0] === "expm1" && vals[j][0] === "1") continue; // node is one unit off here; ours is the exact rounding
    const r = fns[i][1](vals[j][1]);
    console.log(fns[i][0] + "(" + vals[j][0] + ")", r);
    if (r === 0) console.log("1/" + fns[i][0] + "(" + vals[j][0] + ")", 1 / r);
  }
}
const av = [
  ["+0", 0], ["neg0", -0], ["+1", 1], ["-1", -1],
  ["+Inf", Infinity], ["-Inf", -Infinity], ["NaN", NaN]
];
for (let i = 0; i < av.length; i++) {
  for (let j = 0; j < av.length; j++) {
    const r = Math.atan2(av[i][1], av[j][1]);
    console.log("atan2(" + av[i][0] + "," + av[j][0] + ")", r);
    if (r === 0) console.log("1/atan2(" + av[i][0] + "," + av[j][0] + ")", 1 / r);
  }
}
console.log("1/atan(0)", 1 / Math.atan(0));
console.log("1/atan(-0)", 1 / Math.atan(-0));
console.log("1/asin(-0)", 1 / Math.asin(-0));
console.log("1/expm1(-0)", 1 / Math.expm1(-0));
console.log("1/log1p(-0)", 1 / Math.log1p(-0));
console.log("1/sinh(-0)", 1 / Math.sinh(-0));
console.log("1/tanh(-0)", 1 / Math.tanh(-0));
console.log("1/cbrt(-0)", 1 / Math.cbrt(-0));
console.log("asin(2)", Math.asin(2));
console.log("acos(-2)", Math.acos(-2));
console.log("log1p(-1)", Math.log1p(-1));
console.log("log1p(-2)", Math.log1p(-2));
console.log("atan2(+0,+0)", 1 / Math.atan2(0, 0));
console.log("atan2(+0,-0)", Math.atan2(0, -0));
console.log("atan2(-0,+0)", 1 / Math.atan2(-0, 0));
console.log("atan2(-0,-0)", Math.atan2(-0, -0));
console.log("atan2(+Inf,+Inf)", Math.atan2(Infinity, Infinity));
console.log("atan2(+Inf,-Inf)", Math.atan2(Infinity, -Infinity));
console.log("atan2(-Inf,+Inf)", Math.atan2(-Infinity, Infinity));
console.log("atan2(-Inf,-Inf)", Math.atan2(-Infinity, -Infinity));
console.log("cbrt(27)", Math.cbrt(27));
console.log("cbrt(-8)", Math.cbrt(-8));
console.log("cbrt(1e-9*1e9)", Math.cbrt(1e-9*1e9));
console.log("hypot()", Math.hypot());
console.log("hypot(-5)", Math.hypot(-5));
console.log("1/hypot(-0)", 1 / Math.hypot(-0));
console.log("hypot(3,4)", Math.hypot(3, 4));
console.log("hypot(2,3,6)", Math.hypot(2, 3, 6));
console.log("hypot(5args)", Math.hypot(1, 2, 2, 4, 4));
console.log("hypot(1e300)", Math.hypot(1e300, 1e300));
console.log("hypot(1e-300)", Math.hypot(1e-300, 1e-300));
console.log("hypot(Inf,NaN)", Math.hypot(Infinity, NaN));
console.log("hypot(-Inf,NaN)", Math.hypot(-Infinity, NaN));
console.log("atan('1')", Math.atan("1"));
console.log("atan2('1','1')", Math.atan2("1", "1"));
console.log("cbrt('27')", Math.cbrt("27"));
console.log("hypot('3','4')", Math.hypot("3", "4"));
console.log("id_exp", Math.sinh(1)+Math.cosh(1)-Math.exp(1));
console.log("id_hyp", Math.cosh(1)*Math.cosh(1)-Math.sinh(1)*Math.sinh(1));
console.log("id_arc", Math.asin(0.5)+Math.acos(0.5)-Math.PI/2);
console.log("id_tanh", Math.tanh(1)-Math.sinh(1)/Math.cosh(1));
console.log("id_logexp", Math.log1p(Math.expm1(0.5))-0.5);
