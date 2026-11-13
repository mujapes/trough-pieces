var r=/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.){0,10}[a-z]{2,63}$/i;
console.log(r.test("www.npr.org"), r.test("a-.b"), r.test("x.y.z.example.com"));
var s=/^(?:[\w!#$%&'*+\/=?^`{|}~-]{1,63}\.){0,10}\w{1,63}$/;
console.log(s.test("a.b.c"), s.test("..x"));
var t=/(a|bc){2,300}?(b*)$/; console.log(JSON.stringify("xabcabcbbb".match(t)));
var u=/^((\d{1,3})\.){3,200}(\d+)$/; console.log(JSON.stringify("1.22.333.4.5".match(u)));
console.log(/^(?:x{0,100}y){2,50}$/.test("xxyyxy"), /^a{500,600}$/.test("a".repeat(550)), /^a{500,600}$/.test("a".repeat(499)));
console.log(JSON.stringify("aaaa".match(/(a{0,200}?)(a*)/)));
