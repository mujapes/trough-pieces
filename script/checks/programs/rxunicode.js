var r=RegExp("\\p{RI}\\p{RI}|\\p{Emoji}(\\p{EMod}|\\u{FE0F}\\u{20E3}?|[\\u{E0020}-\\u{E007E}]+\\u{E007F})?(\\u{200D}\\p{Emoji}(\\p{EMod}|\\u{FE0F}\\u{20E3}?|[\\u{E0020}-\\u{E007E}]+\\u{E007F})?)*|.","gu");
console.log("a👍🏽b🇫🇷c".match(r).length, "x😀y".match(/./gu).length, /\u{1F600}/u.test("😀"), /[\u{1F600}-\u{1F64F}]/u.test("😃"), /^\p{L}+$/u.test("héllo"), /\P{L}/u.test("abc"));
