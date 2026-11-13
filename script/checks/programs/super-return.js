var pre=null;
class B{constructor(){if(pre){var p=pre;pre=null;return p}this.made=1}}
class X extends B{constructor(){super();this.y=2}get d(){return 'D'}}
var o={old:1};pre=o;Object.setPrototypeOf(o,X.prototype);var r=new X();
console.log(r===o, r.old, r.y, r.d, r instanceof X);
