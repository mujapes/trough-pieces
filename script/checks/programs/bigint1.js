var a=BigInt("-9223372036854775808"),b=BigInt(0),c=BigInt(" 0x1F "),d=BigInt(12),e=BigInt(true);
console.log(a.toString(),b.toString(),c.toString(),d.toString(),e.toString(),String(BigInt("007")));
console.log(Number(BigInt("42"))+1, BigInt(5)<BigInt(7));
try{BigInt(1.5)}catch(x){console.log(x.name)}try{BigInt("abc")}catch(x){console.log(x.name)}try{new BigInt(1)}catch(x){console.log(x.name)}
