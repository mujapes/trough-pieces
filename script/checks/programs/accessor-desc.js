class C{ get s(){ throw TypeError('called') } }
var d=Object.getOwnPropertyDescriptor(C.prototype,'s');
console.log(typeof d.get, d.set, d.configurable, 'value' in d);
Object.defineProperty(C.prototype,'s',{...d,enumerable:false});
console.log(typeof Object.getOwnPropertyDescriptor(C.prototype,'s').get);
var o={get x(){return 1}}; console.log(JSON.stringify(Object.getOwnPropertyDescriptor(o,'x')));
