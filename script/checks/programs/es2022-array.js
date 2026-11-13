console.log([1,[2,[3,[4]]]].flat().length,[1,[2,[3,[4]]]].flat(Infinity).join(),[1,2].flatMap(x=>[x,x*2]).join());
console.log([1,2,3].at(-1),'abc'.at(-2),[1,2,3,4].findLast(x=>x%2),[1,2,3,4].findLastIndex(x=>x>9));
var a=[3,1,2];console.log(a.toSorted().join(),a.toReversed().join(),a.with(0,9).join(),a.join());
console.log([1,2,3,4,5].copyWithin(0,3).join(),Object.hasOwn({x:1},'x'),Object.hasOwn({},'toString'));
console.log("a".localeCompare("b"),"b".localeCompare("a"));
