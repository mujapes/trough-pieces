var o={length:2,0:'a',1:'b'};console.log(Array.prototype.push.call(o,'c','d'),o[3],o.length);
var a=[1];console.log(a.push(2,3),a.join());var s=0,b=[];for(var i=0;i<20000;i++)b.push(i);console.log(b.length);
