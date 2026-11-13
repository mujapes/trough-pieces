var r = { c: function (n) { return n + 1 }, name: 'r', who: function () { return this.name }, deep: { list: [10, 20], f: null } }, z = null, u;
console.log(r?.c?.(1), z?.c?.(1), r.d?.(2), r?.['c'](3), z?.[0], u?.a.b.c.d, r?.deep?.list?.[1], r.deep.f?.(), r.deep?.nope?.x.y);
console.log(r.who?.(), r?.who(), r['who']?.(), r.none?.(sideEffect()), typeof z?.x, (z?.x) === undefined, r?.deep.list.length);
function sideEffect() { console.log('must not run'); return 1 }
var f = null, g = function () { return 'called' }; console.log(f?.(), g?.(), g?.call?.(null), 1 ? .5 : 2, r?.c(1) + 1, (r?.c)(5));
function h(o) { try { o.x() } catch (e) { } if (o) { let s; try { s = o?.v ?? 'none' } catch (e) { } const k = [s]; return (function () { return k[0] + '!' })() } }
console.log(h({ v: 'v' }), h({}));
var a = { b: { c: 1 } }; a.b.c++; console.log(a.b.c, a?.b?.c?.toString?.(), [1, 2]?.map?.(function (x) { return x * 2 })?.join?.('-'));
function get(of) { return 'got ' + of } function set(get, async) { return get + async } function outer() { function get(x) { return x * 2 } var of = 3, set = get(of); return (function () { return set + get(1) })() }
console.log(get('it'), set(1, 2), outer(), (function (static, await) { return static - await })(9, 4));
var base = { a: 1, b: 2 }, more = { b: 3, c: 4 }, sp = { ...base, ...more, d: 5, ...null, ...undefined, a: 9 };
console.log(JSON.stringify(sp), JSON.stringify({ ...base }), JSON.stringify({ x: 0, ...(more.c > 3 ? { y: 1 } : {}), ['k' + 1]: 2 }), base.c);
var short = (function () { function get() { return 1 } var set = 2, of = 3, plain = 4; return { get, set, of, plain, get z() { return 26 } } })(); console.log(short.get(), short.set, short.of, short.plain, short.z);
