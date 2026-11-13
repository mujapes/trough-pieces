function P(a){this.a=a}
var r=Reflect.construct(P,[3]);console.log(r.a, r instanceof P, Reflect.apply(Math.max,null,[1,5,2]));
var o={x:1};Reflect.set(o,'y',2);console.log(Reflect.get(o,'y'),Reflect.has(o,'x'),Reflect.ownKeys(o).join(),Reflect.deleteProperty(o,'x'),Reflect.has(o,'x'));
