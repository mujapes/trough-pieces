// promises, the job queue, timers
var log = [];
function say(x) { log.push(x); }
say('start');
setTimeout(function () { say('t10'); }, 80);
setTimeout(function (a, b) { say('t5 ' + a + b); Promise.resolve().then(function () { say('t5 micro'); }); }, 40, 'x', 'y');
setTimeout(function () { say('t0'); }, 0);
var n = 0, iv = setInterval(function () { say('iv' + (++n)); if (n === 3) clearInterval(iv); }, 56);
var dead = setTimeout(function () { say('never'); }, 24); clearTimeout(dead);
queueMicrotask(function () { say('micro1'); });
var p = new Promise(function (ok) { say('executor'); ok(1); });
p.then(function (v) { say('then ' + v); return v + 1; }).then(function (v) { say('then ' + v); throw new Error('boom'); })
  .then(function () { say('skipped'); }).catch(function (e) { say('caught ' + e.message); return 'ok'; })
  .finally(function () { say('finally'); }).then(function (v) { say('after ' + v); });
Promise.resolve(Promise.resolve(5)).then(function (v) { say('same ' + v); });
new Promise(function (ok) { ok(Promise.resolve(6)); }).then(function (v) { say('adopted ' + v); });
Promise.resolve().then(function () { say('a1'); }).then(function () { say('a2'); }).then(function () { say('a3'); }).then(function () { say('a4'); });
Promise.reject(new TypeError('bad')).then(null, function (e) { say('rej ' + (e instanceof TypeError)); });
new Promise(function (ok, no) { no(1); ok(2); no(3); }).then(function (v) { say('no ' + v); }, function (e) { say('once ' + e); });
new Promise(function () { throw 'thrown'; }).catch(function (e) { say('exec ' + e); });
({ then: function (ok) { ok('thenable'); } }, Promise.resolve({ then: function (ok) { ok('thenable'); } }).then(say));
function wait(ms, v, fail) { return new Promise(function (ok, no) { setTimeout(function () { (fail ? no : ok)(v); }, ms); }); }
Promise.all([wait(160, 'a'), 2, wait(96, 'c')]).then(function (v) { say('all ' + JSON.stringify(v)); });
Promise.all([]).then(function (v) { say('all0 ' + v.length); });
Promise.all([wait(240, 1), wait(120, 'e', true)]).catch(function (e) { say('allfail ' + e); });
Promise.race([wait(320, 'slow'), wait(200, 'fast')]).then(function (v) { say('race ' + v); });
Promise.allSettled([wait(64, 1), wait(72, 2, true)]).then(function (v) { say('settled ' + JSON.stringify(v)); });
Promise.any([wait(400, 'x', true), wait(360, 'y')]).then(function (v) { say('any ' + v); });
Promise.any([Promise.reject(1), Promise.reject(2)]).catch(function (e) { say('anyfail ' + e.name + ' ' + e.errors); });
var chain = Promise.resolve(0); [1, 2, 3].forEach(function (k) { chain = chain.then(function (s) { return wait(160, s + k); }); });
chain.then(function (s) { say('chain ' + s); });
try { Promise(); } catch (e) { say('new ' + (e instanceof TypeError)); }
say(typeof p.then + ' ' + (p instanceof Promise) + ' ' + (p.then(function () {}) !== p));
setTimeout(function () { setTimeout(function () { say('nested'); console.log(log.join('\n')); }, 800); }, 800);
say('end');
