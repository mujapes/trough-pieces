async function* g(n){ for(let i=0;i<n;i++){ const v=await Promise.resolve(i*10); yield v+1 } return 'end' }
var it=g(3), out=[];
function pull(){ return it.next().then(r=>{ out.push(JSON.stringify(r)); if(!r.done) return pull(); console.log(out.join(' ')) }) }
pull();
async function* h(){ try{ yield 1; yield 2 } finally { console.log('cleanup') } }
var hi=h(); hi.next().then(r=>{ console.log('h',r.value); return hi.return(9) }).then(r=>console.log('ret',JSON.stringify(r)));
async function* bad(){ yield 1; throw new Error('boom') }
var b=bad(); b.next().then(()=>b.next()).catch(e=>console.log('caught',e.message));
var o={ async *m(){ yield await Promise.resolve('x') } }; o.m().next().then(r=>console.log('method',r.value));
console.log(typeof g(1)[Symbol.asyncIterator], typeof it.next);
