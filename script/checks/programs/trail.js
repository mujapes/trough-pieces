// the call trail of an error: the line of each place, newest first (columns differ from node by design)
function a(){return b()}
function b(){
  return new Error('x').stack}
var s=a().split('\n').slice(1,4).map(function(l){var m=/:(\d+):\d+\)?$/.exec(l);return m&&m[1]});
console.log(s.join(' '));
function c(){ return a() } console.log(c().split('\n').length>4);
