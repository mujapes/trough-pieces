function f(l,e){ return "a"===e?delete l?.[1]:3 } console.log(f({1:2},"a"))
var l={1:2}; console.log(delete l?.[1])
function g(l){return delete l?.[1]} console.log(g({1:2}))
var l={1:2,a:{b:1}},n=null;console.log(delete l?.[1], l[1], delete n?.x, delete l.a?.b, l.a.b, delete l?.zz, delete n?.[1]?.y, delete l.a);
function f(l,e){ return "a"===e?delete l?.[1]:3 } console.log(f({1:2},"a"), f(null,"a"));
