function* count(n){ for (var i=0;i<n;i++){ var got = yield i; if (got) console.log('got', got) } return 'end' }
var g = count(3);
console.log(JSON.stringify(g.next()), JSON.stringify(g.next('a')), JSON.stringify(g.next()), JSON.stringify(g.next()), JSON.stringify(g.next()));
function* inner(){ yield 1; yield 2 }
function* outer(){ yield 0; yield* inner(); yield* [7,8]; try { yield 3 } catch (e) { console.log('caught', e); yield 4 } finally { console.log('fin') } }
console.log([...outer()].join());
var o = outer(); o.next(); o.next(); o.next(); o.next(); o.next(); o.next();
console.log(JSON.stringify(o.throw('boom')), JSON.stringify(o.next()));
function* fib(){ let a=0,b=1; while(true){ yield a; [a,b]=[b,a+b] } }
var f = fib(), s=[]; for (var k=0;k<10;k++) s.push(f.next().value); console.log(s.join(' '));
console.log(JSON.stringify(f.return(5)), JSON.stringify(f.next()));
var obj = { *items(){ yield this.a; yield this.b }, a: 1, b: 2 };
for (const x of obj.items()) console.log(x);
class C { constructor(){ this.v=[4,5] } *[Symbol.iterator](){ for (const x of this.v) yield x*2 } }
console.log([...new C()].join());
function* withfn(a){ var add = function(x){ return x + a }; a = yield add(1); yield add(1) }
var w = withfn(10); console.log(w.next().value, w.next(20).value);
