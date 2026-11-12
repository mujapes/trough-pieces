const obj = { a: 7, b: "ok" };
const double = (x) => x * 2;
console.log(`plain template`, ``, ``.length, `left` + `right`, `${""}`);
console.log(`math:${1 + 2 * 3}`, `call:${double(8)}`, `tern:${obj.a > 5 ? "hi" : "lo"}`);
console.log(`prop:${obj.a}-${obj["b"]}`, `braces:${"}"}-${'{'}-${"\"'}{"}`);
console.log(`nest:${`lvl1:${`lvl2:${obj.a + 1}`}`}`, `dollar:$100 $ $x $`);
console.log(`types:${0}:${-3.5}:${null}:${undefined}:${true}:${false}:${[1, "two", null, undefined, 5]}`);
const esc = `n:\n t:\t bt:\` dl:\$ bs:\\ A:\x41`;
console.log(esc.length, esc);
const multi = `line1
line2:${obj.b}
line3`;
console.log(multi.length, multi);
