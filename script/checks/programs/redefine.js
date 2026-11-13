function init(t){let r=Object.getOwnPropertyDescriptor(t,"shape"),i=r&&r.get?r.get.raw:t.shape??{};if(i){let e=()=>{let n={...i};return Object.defineProperty(t,"shape",{value:n}),e.raw=n,n};e.raw=i,Object.defineProperty(t,"shape",{get:e})}}
function y(e){let t=Object.getOwnPropertyDescriptor(e,"shape");return t?.get?t.get.raw:t?.value}
var def={type:"object",shape:{a:1,b:2}};init(def);console.log(Object.keys(y(def)).join());
console.log(Object.keys(def.shape).join(),Object.keys(y(def)).join(),Object.keys(def.shape).join());
var d2={...def};console.log(Object.keys(d2).join(), d2.shape&&Object.keys(d2.shape).join());
init(d2);console.log(Object.keys(d2.shape).join());
