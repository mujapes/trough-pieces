var o={toString(){return 'a'},valueOf(){return 1}};
console.log(String(o), String(123n), String(0xffn), String(BigInt("99999999999999999999")), String(-5n));
var o={toString(){return 'a'},valueOf(){return 1}};
console.log(`${o}|${1}|${null}|${[1,2]}|${{}}`, `x${o}y`);
