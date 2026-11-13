const A={m(){function f(){f=1;return 1}return f()}};try{console.log(A.m())}catch(e){console.log('A',String(e))}
const B={m:function(){function f(){f=1;return 1}return f()}};try{console.log(B.m())}catch(e){console.log('B',String(e))}
var C={m(){function f(){f=1;return 1}return f()}};try{console.log(C.m())}catch(e){console.log('C',String(e))}
const D=[function(){function f(){f=1;return 1}return f()}];try{console.log(D[0]())}catch(e){console.log('D',String(e))}
const E={m(){var f=function(){};f=1;return 1}};try{console.log(E.m())}catch(e){console.log('E',String(e))}
