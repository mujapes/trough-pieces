var o={a:1}; Object.defineProperty(o,'h',{value:2}); Object.defineProperty(o,'v',{value:3,enumerable:true});
console.log(Object.keys(o).join(), o.h, JSON.stringify(o), 'h' in o, o.hasOwnProperty('h'));
for (var k in o) console.log(k); console.log(Object.keys(o).join());
var p={...o}; console.log(Object.keys(p).join());
