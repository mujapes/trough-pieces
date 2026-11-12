var [v1, , v3 = 30, v4 = 40] = [10, 20, undefined];
let [head, ...tail] = [1, 2, 3, 4];
const [n1, [n2, [n3]], [s1, , s3]] = [5, [6, [7]], "abc"];
console.log(v1, v3, v4, head, "" + tail, n1, n2, n3, s1, s3);
let swA = "left", swB = "right";
[swA, swB] = [swB, swA];
console.log(swA, swB, "" + ([v1, head] = [11, 22]), v1, head);
const key = "dyn";
const { a, b: renamed, c = 99, [key]: dv, "str-k": sk, 0: nk } = { a: 1, b: 2, dyn: 3, "str-k": 4, 0: 5 };
console.log(a, renamed, c, dv, sk, nk);
const { out: { in1, in2 = 8 }, arr: [, { deep }, ...restObj] } = { out: { in1: 7 }, arr: [0, { deep: "ok" }, 9, 10] };
console.log(in1, in2, deep, "" + restObj);
let pa = 0, pb = 0, bag = {};
const assignVal = ({ a: pa, b: pb = 50 } = { a: 15 });
[bag.x, bag["y"], { z: bag.z }] = [100, 200, { z: 300 }];
console.log(pa, pb, assignVal.a, bag.x, bag.y, bag.z);
function fn({ a, b = 2 }, [c, d = 4]) { return a + ":" + b + ":" + c + ":" + d; }
const arrow = ({ x: ax = 5 }, [ay, ...az]) => ax + ":" + ay + ":" + az;
console.log(fn({ a: 1 }, [3]), fn({ a: 8, b: 9 }, [10, 11]), arrow({}, [6, 7, 8]));
const pairs = [["k1", 10], ["k2", 20], ["k3", 30]];
let loopOut = "";
for (const [k, v] of pairs) { loopOut = loopOut + k + "=" + v + ";"; }
console.log(loopOut);
