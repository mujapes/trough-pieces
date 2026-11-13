var n={a:1,b:2};
function f(){let e={},t=Object.keys(n);for(let i=t.length,n=0;n<i;n++)e[t[n]]={d:-1};return e}
console.log(JSON.stringify(f()));
function g(e){var a=class e{static create(t){return new e(t)}constructor(t){this.t=t}};return a.create(5).t}
console.log(g(1));
function h(e,t,n){var a=class e{static m(){let x=new e;return x instanceof e}};return a.m()}
console.log(h(1));
var M=(function(i){let n={red:{green:1},green:{blue:1},blue:{}};return function(e){let t=function(e){let t=function(){let e={},t=Object.keys(n);for(let i=t.length,n=0;n<i;n++)e[t[n]]={distance:-1,parent:null};return e}(),i=[e];for(t[e].distance=0;i.length;){let e=i.pop(),r=Object.keys(n[e]);for(let n=r.length,s=0;s<n;s++){let n=r[s],o=t[n];-1===o.distance&&(o.distance=t[e].distance+1,o.parent=e,i.unshift(n))}}return t}(e);return JSON.stringify(t)}})();
console.log(M('red'));
