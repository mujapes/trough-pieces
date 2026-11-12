var a=[1,'two',null,undefined,3.5,true,NaN,-0,'ü','\u4e2d'];
console.log(a.join(),'|',a.join(''),'|',a.join(' - '),'|',a.join('\u4e2d').length,[].join(),[null].join(),[1].join('x'),[,'a',,].join('+'),[,].length,[1,,2,].length,[,...[1],,3].join());
console.log([1,[2,[3,4]],{}].join(';'),[{toString:function(){return 'T'}},2].join(),a.join(undefined),a.join(null),a.join(0));
console.log(a.indexOf('two'),a.indexOf(NaN),a.indexOf(0),a.indexOf(null),a.indexOf(undefined),a.indexOf(3.5,5),a.indexOf(3.5,-6),a.indexOf(1,-100),a.indexOf('t'+'wo',1),a.indexOf(true),a.indexOf('x'));
var o={},b=[o,{},o];console.log(b.indexOf(o),b.indexOf(o,1),b.indexOf({}),b.indexOf(o,3),b.indexOf(o,2.9));
console.log(a.slice(1,3).join(),a.slice(-2).join(),a.slice().length,a.slice(4,2).length,a.slice(-100,2).join(),a.slice(8,100).join(''),a.slice(undefined,-8).join(),a.slice('1','2').join(),a.slice(1.9,3.9).join());
function f(){return Array.prototype.slice.call(arguments,1).join('/')+':'+Array.prototype.indexOf.call(arguments,'c')+':'+Array.prototype.join.call(arguments,'')}
console.log(f('a','b','c'),Array.prototype.join.call({length:2,0:'p',1:'q'},'&'),Array.prototype.slice.call('xyz').join('-'));
var big=[];for(var i=0;i<4000;i++)big.push(i%7?i:'s'+i);var s=big.join(',');console.log(s.length,s.substring(0,20),big.indexOf('s3997'),big.indexOf(3999),big.slice(3990).join(' '));
