var total = 1; let seen = []; const NAME = 'page';
function add(n){ total += n; seen.push(n); return total }
class Box { constructor(v){ this.v = v } get twice(){ return this.v * 2 } }
setTimeout(function(){ console.log('timer from one, total', total) }, 5);
console.log('one', add(2));
