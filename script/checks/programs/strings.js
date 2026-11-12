
console.log("a\tb\\c\"d\'e", 'q"q', "\x41B\u{43}\u{1F600}😀", "café", "line\
joined", "\a\q\/");
console.log("abc" < "abd", "abc" < "ab", "a" < "B", "10" < "9", 10 < "9", "10" < 9, "" < "a", "a" + 1 + 2, 1 + 2 + "a", "x" + null + undefined + true);
console.log("é" + "ü", "日本語", "😀" + "!");
var s = "ab"; var i = 0; while (i < 12) { s += s; i++; } console.log(typeof s, s == s + "", s === "ab", s != "");
console.log("5" == 5, "5" === 5, "" == 0, " \n" == 0, "a" == "a", null == 0, null >= 0, undefined == 0, NaN == NaN, NaN != NaN, true == 1, true === 1, "true" == true, "1" == true);
