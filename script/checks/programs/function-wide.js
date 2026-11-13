var f = new Function('a', 'return a + "é→😀" + "ÿ".length');
console.log(f('x'), f('x').length);
var g = Function('return "plain"'); console.log(g());
var h = new Function('/* ü */ var s = "ñ"; return s.charCodeAt(0)'); console.log(h());
