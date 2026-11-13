function m(t){Object.defineProperty(t,'dw',{enumerable:true,get:()=>b});var n=1;class b{constructor(x){this.x=x}}return t}
var t=m({}); console.log(typeof t.dw, new t.dw(3).x);
function m2(t){t.f=()=>b;class b{}} var u={};m2(u);console.log(typeof u.f());
