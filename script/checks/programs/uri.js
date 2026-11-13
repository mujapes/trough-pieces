var s = 'a b&c=d/é?😀#~!(x)';
console.log(encodeURIComponent(s)); console.log(encodeURI(s));
console.log(decodeURIComponent(encodeURIComponent(s)) === s, decodeURI(encodeURI(s)) === s, decodeURIComponent('%E2%82%AC+%41'), decodeURI('%2Fa%20b%23'));
try { decodeURIComponent('%E2%82') } catch (e) { console.log(e.name, e.message) }
try { decodeURIComponent('%zz') } catch (e) { console.log(e.message) }
console.log(encodeURIComponent(12.5), encodeURIComponent(''), encodeURIComponent(null));
console.log(String.fromCodePoint(65, 0x20ac, 0x1f600), '😀a'.codePointAt(0), '😀a'.codePointAt(1), '😀a'.codePointAt(2), 'x'.codePointAt(5));
