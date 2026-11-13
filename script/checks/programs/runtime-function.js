// [by Opus] new Function, and a var list ended by a line break before return (Guardian polyfills)
var D={k:5};
console.log((function(){var n=1
return function(){},D.k})());
console.log(typeof (function(){var n
return D.k,function(){}})());
var add=new Function("a","b","return a+b");console.log(add(2,3), typeof new Function("return function Document() {}")());
try{new Function("return (")}catch(e){console.log(e instanceof SyntaxError)}
console.log(new Function("x","var y=x*2;function h(){return y+1}return h()")(5));
