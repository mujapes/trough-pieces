// dates: the calendar, reading and writing date text, setters, and objects as numbers
function show(l, v) { console.log(l, JSON.stringify(v)); }
var d = new Date(Date.UTC(2024, 1, 29, 13, 45, 30, 123));
show('iso', [d.toISOString(), d.getTime(), d.valueOf() === +d, JSON.stringify(d), typeof Date.now()]);
show('get', [d.getFullYear(), d.getMonth(), d.getDate(), d.getDay(), d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds(), d.getTimezoneOffset()]);
show('utc', [d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), d.getUTCDay(), d.getUTCHours()]);
show('text', [d.toString(), d.toDateString(), d.toTimeString(), d.toUTCString(), String(d), '' + d, d + 1]);
show('locale', [d.toLocaleDateString('en-US'), d.toLocaleTimeString('en-US'), d.toLocaleString('en-US'), new Date(2001, 8, 9, 0, 5).toLocaleTimeString('en-US')]);
show('ctor', [new Date(0).toISOString(), new Date(2020, 0).toISOString(), new Date(99, 11, 31, 23, 59, 59, 999).toISOString(), new Date(2021, 12, 0).toISOString(), new Date(2021, -1, 1).toISOString(), new Date(d).getTime() === d.getTime(), new Date(1e12 + 0.9).getTime(), new Date(-1.5).getTime()]);
var days = [-719468, -146097, -1, 0, 59, 60, 365, 11016, 19782, 2932896, -100000000, 100000000];
show('days', days.map(function (n) { var x = new Date(n * 864e5); return isNaN(x) ? 'bad' : x.toISOString() + ' ' + x.getUTCDay(); }));
show('leap', [1900, 2000, 2023, 2024, 2100, 2400].map(function (y) { return new Date(Date.UTC(y, 2, 0)).getUTCDate(); }));
show('range', [new Date(8.64e15).toISOString(), new Date(-8.64e15).toISOString(), new Date(8.64e15 + 1).getTime(), Date.UTC(275760, 8, 13), Date.UTC(275760, 8, 14), new Date(-1, 0, 1).toISOString(), new Date(-62198755200000).toISOString()]);
show('parse', ['2024-02-29', '2024-02-29T13:45:30Z', '2024-02-29T13:45:30.5+05:30', '2024-02-29T13:45', '2024', '2024-06', '+002024-01-01T00:00:00Z', '2024-13-01', '2024-02-29T24:00:00Z', '2024-02-29T25:00', 'Thu Feb 29 2024 13:45:30 GMT+0200 (EET)', 'Thu, 29 Feb 2024 13:45:30 GMT', 'Feb 29, 2024', '29 February 2024 10:00', 'February 29, 2024 10:20:30', '2/29/2024', 'rubbish', ''].map(function (s) { return Date.parse(s); }));
show('round', [Date.parse(d.toString()), Date.parse(d.toUTCString()), Date.parse(d.toISOString()), new Date(d.toISOString()).getTime()]);
var e = new Date(Date.UTC(2023, 0, 31));
show('set', [e.setMonth(1), e.toISOString(), e.setDate(0), e.toISOString(), e.setFullYear(2020, 1, 29), e.setHours(25, 61, 61, 1001), e.toISOString(), e.setUTCMinutes(-1), e.setSeconds(), isNaN(e), e.setFullYear(2000), e.toISOString(), e.setTime(5), e.setMilliseconds(-6)]);
var bad = new Date('nope');
show('bad', [bad.getTime(), bad.getFullYear(), bad.getDay(), String(bad), bad.toJSON(), isNaN(bad), bad.setDate(3), new Date(NaN).getTime(), new Date(2020, 0, NaN).getTime()]);
try { bad.toISOString(); } catch (x) { show('err', [x instanceof RangeError, x.message]); }
var a = new Date(2020, 0, 1), b = new Date(2020, 0, 2);
show('num', [b - a, a < b, a > b, a <= a, +a, -a, a * 1, (b - a) / 36e5, b - 0 === b.getTime(), [b, a].sort(function (x, y) { return x - y; })[0] === a]);
var o = { valueOf: function () { return 42; } }, o2 = { toString: function () { return '7'; } };
show('valueOf', [o - 2, o * 2, -o, +o, o < 43, o + 1, o2 - 2, o2 * '3', +o2, o2 + 1, [5] - 1, ({}) - 1]);
show('add', (function () { var x = new Date(Date.UTC(2024, 0, 31)); x.setUTCDate(x.getUTCDate() + 30); return x.toISOString(); })());
show('week', (function () { var x = new Date(Date.UTC(2024, 5, 12)); x.setUTCDate(x.getUTCDate() - x.getUTCDay()); return x.toUTCString(); })());
show('age', Math.floor((Date.UTC(2024, 5, 12) - Date.UTC(1990, 6, 4)) / (365.25 * 864e5)));
