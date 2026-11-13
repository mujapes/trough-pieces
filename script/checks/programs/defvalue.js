var P={};Object.defineProperty(P,'x',{configurable:true,get(){console.log('get');return 1},set(v){console.log('set',v)}});
var o=Object.create(P);Object.defineProperty(o,'x',{configurable:true,writable:true,enumerable:true,value:5});
console.log(o.x,Object.getOwnPropertyNames(o).join());
var q={};Object.defineProperty(q,'y',{configurable:true,get(){return 1},set(v){console.log('qset')}});
Object.defineProperty(q,'y',{configurable:true,writable:true,value:7});console.log(q.y);
