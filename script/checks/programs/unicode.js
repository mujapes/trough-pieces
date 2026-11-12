var s = "héllo", w = "日本語", e = "a😀b", m = s + w;
console.log(s, w, e, m, s.length, w.length, e.length, m.length, s[1], w[2], m[5], m[9], "é" === "é", "\xe9" == s[1]);
console.log("é" < "z", "z" < "é", "日" > "é", "a" < "日", w < w + "x", "日" === w[0], "😀" === "😀", "😀".length, e[0] + e[3]);
var o = { "ключ": 1, é: 2 }; o[w] = 3; o["é"] += 10; var ks = ""; for (var k in o) ks += k + o[k] + " "; console.log(ks, "ключ" in o, o.é);
var out = ""; for (var c of "añ日") out = c + out; console.log(out, out.length, typeof w[0], "ÿ".length, "Ā".length, +"é", +" 12 ", "é" + 1);
console.log("tab\there", "q\"uote", 'it\'s', "\u{1F600}".length, "\u{41}", "x" + "ÿ" + "Ā", ("ÿ" + "Ā").length);
