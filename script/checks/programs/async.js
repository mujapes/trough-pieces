function later(ms, v){ return new Promise(function(r){ setTimeout(function(){ r(v) }, ms) }) }
async function one(){ console.log('one starts'); var a = await later(20, 'A'); console.log('one has', a); return a + '!' }
async function two(){ try { await Promise.reject(new Error('no')); } catch (e) { console.log('two caught', e.message) } finally { console.log('two finally') } return 2 }
async function three(){ throw new TypeError('bad') }
const four = async (x) => (await x) * 2;
const five = async x => { const r = []; for (const p of [later(40,'p'), 'q', later(10,'r')]) r.push(await p); return r.join('') };
var o = { async m(){ return await this.v }, v: 'method' };
class K { async go(n){ let t = 0; for (let i = 1; i <= n; i++) t += await i; return t } static async make(){ return new K() } }
console.log('start');
one().then(function(v){ console.log('one gives', v) });
two().then(function(v){ console.log('two gives', v) });
three().catch(function(e){ console.log('three fails', e.name, e.message) });
four(Promise.resolve(21)).then(function(v){ console.log('four', v) });
five().then(function(v){ console.log('five', v) });
o.m().then(function(v){ console.log(v) });
K.make().then(function(k){ return k.go(4) }).then(function(v){ console.log('sum', v) });
(async function(){ var a = await one(); var b = await Promise.all([four(1), four(2)]); console.log('all', a, b.join()); })();
Promise.resolve().then(function(){ console.log('tick') });
console.log('end of script');
