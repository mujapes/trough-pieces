// R: a number's text cut to 14 digits: the reference engines are a unit off in places (checks/arcs.py is the exact check)
function R(x){if(typeof x!=='number')return x;var s=String(x),k=s.indexOf('e'),m=k<0?s:s.substring(0,k);return (m.length>15?m.substring(0,15):m)+(k<0?'':s.substring(k))}
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
    const r = Math.round(fns[i][1](vals[j][1]) * 1e12) / 1e12; // the references are a unit off for some (expm1(1), log1p(2)); checks/arcs.py is the exact check
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
console.log("1/atan(0)", R(1 / Math.atan(0)));
console.log("1/atan(neg0)", R(1 / Math.atan(-0)));
console.log("1/asin(neg0)", R(1 / Math.asin(-0)));
console.log("1/expm1(neg0)", R(1 / Math.expm1(-0)));
console.log("1/log1p(neg0)", R(1 / Math.log1p(-0)));
console.log("1/sinh(neg0)", R(1 / Math.sinh(-0)));
console.log("1/tanh(neg0)", R(1 / Math.tanh(-0)));
console.log("1/cbrt(neg0)", R(1 / Math.cbrt(-0)));
console.log("asin(2)", R(Math.asin(2)));
console.log("acos(-2)", R(Math.acos(-2)));
console.log("log1p(-1)", R(Math.log1p(-1)));
console.log("log1p(-2)", R(Math.log1p(-2)));
console.log("atan2(+0,+0)", R(1 / Math.atan2(0, 0)));
console.log("atan2(+0,neg0)", R(Math.atan2(0, -0)));
console.log("atan2(neg0,+0)", R(1 / Math.atan2(-0, 0)));
console.log("atan2(neg0,neg0)", R(Math.atan2(-0, -0)));
console.log("atan2(+Inf,+Inf)", R(Math.atan2(Infinity, Infinity)));
console.log("atan2(+Inf,-Inf)", R(Math.atan2(Infinity, -Infinity)));
console.log("atan2(-Inf,+Inf)", R(Math.atan2(-Infinity, Infinity)));
console.log("atan2(-Inf,-Inf)", R(Math.atan2(-Infinity, -Infinity)));
console.log("cbrt(27)", R(Math.cbrt(27)));
console.log("cbrt(-8)", R(Math.cbrt(-8)));
console.log("cbrt(1e-9*1e9)", R(Math.cbrt(1e-9*1e9)));
console.log("hypot()", R(Math.hypot()));
console.log("hypot(-5)", R(Math.hypot(-5)));
console.log("1/hypot(neg0)", R(1 / Math.hypot(-0)));
console.log("hypot(3,4)", R(Math.hypot(3, 4)));
console.log("hypot(2,3,6)", R(Math.hypot(2, 3, 6)));
console.log("hypot(5args)", R(Math.hypot(1, 2, 2, 4, 4)));
console.log("hypot(1e300)", R(Math.hypot(1e300, 1e300)));
console.log("hypot(1e-300)", R(Math.hypot(1e-300, 1e-300)));
console.log("hypot(Inf,NaN)", R(Math.hypot(Infinity, NaN)));
console.log("hypot(-Inf,NaN)", R(Math.hypot(-Infinity, NaN)));
console.log("atan('1')", R(Math.atan("1")));
console.log("atan2('1','1')", R(Math.atan2("1", "1")));
console.log("cbrt('27')", R(Math.cbrt("27")));
console.log("hypot('3','4')", R(Math.hypot("3", "4")));
console.log("id_exp", R(Math.sinh(1)+Math.cosh(1)-Math.exp(1)));
console.log("id_hyp", R(Math.cosh(1)*Math.cosh(1)-Math.sinh(1)*Math.sinh(1)));
console.log("id_arc", R(Math.asin(0.5)+Math.acos(0.5)-Math.PI/2));
console.log("id_tanh", R(Math.tanh(1)-Math.sinh(1)/Math.cosh(1)));
console.log("id_logexp", R(Math.log1p(Math.expm1(0.5))-0.5));
