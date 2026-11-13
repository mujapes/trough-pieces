var log=[];var p=new Proxy({a:1},{get:function(t,k,r){log.push('g'+k);return k in t?t[k]:'none:'+k},set:function(t,k,v){log.push('s'+k);t[k]=v*2;return true}});
console.log(p.a,p.zz,p['b']);p.c=5;console.log(p.c,log.join());
var q=new Proxy({x:3},{});q.y=4;console.log(q.x,q.y,typeof Proxy);
var f=new Proxy(function(a){return a+1},{apply:function(t,th,args){return t(args[0])*10}});console.log(f(2));
function g(){return 1};g.tag=7;var p=new Proxy(g,{});console.log(p(),p.tag);
