var s=0;for(var i=0;i<20000;i++){s+=eval("1+2");s+=new Function("a","return a*2")(i)}console.log(s);
var f=new Function("return 1"),g=new Function("return 1");f.x=1;console.log(f===g,g.x,g());
var url="a'b";console.log(`'${url.replace(/'/g, "\\'")}'`);
console.log(`${"}"}x`, `${`in${1}`}`);
