const a = [2, 3], b = [5, 6];
console.log("" + [...a], "" + [1, ...a, 4, ...b], "" + [...[]], "" + [9, ...[], 8]);
console.log("" + [..."hey"], "" + [0, ...[1, ...a, ...[..."ab"]], 7]);
const sum4 = (w, x, y, z = 0) => w + x * 10 + y * 100 + z * 1000;
console.log(sum4(...[1, 2, 3]), sum4(4, ...a, 5), sum4(6, ...[], ...a));
const obj = { base: 100, m: function(x, y, z) { return this.base + x + y + z; } };
console.log(obj.m(...[1, 2, 3]), obj.m(10, ...a));
function Box(x, y, z) { this.total = x + "-" + y + "-" + z; }
Box.prototype.tag = "box";
console.log(new Box(1, ...a) instanceof Box, new Box(1, ...a).tag, new Box(1, ...a).total, new Box(...b, 7).total);
function withRest(first, ...rest) { return first + ":" + rest.length + ":" + rest + ":" + arguments.length + ":" + arguments[2]; }
console.log(withRest(...[10, 20, 30, 40]), withRest(1, ...a, ...b));
console.log(...[1, "two", 3, "four", ...a]);
