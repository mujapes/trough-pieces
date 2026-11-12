// The library's half that is written in the language (see lib.S). __n(k): the built-in routine numbered k.
__n(-7);
function Object(){}function Array(){}function Function(){}function String(x){return arguments.length?''+x:''}
function Number(x){return arguments.length?+x:0}function Boolean(x){return !!x}
__n(-1,Object.prototype);__n(-2,Array.prototype);__n(-3,Function.prototype);__n(-4,String.prototype);__n(-5,Number.prototype);__n(-6,Boolean.prototype);
var Math={floor:__n(1),ceil:__n(2),abs:__n(3),sqrt:__n(4),round:__n(5),trunc:__n(6),sign:__n(7),min:__n(8),max:__n(9),exp:__n(20),log:__n(21),log2:__n(22),log10:__n(23),random:__n(24),sin:__n(25),cos:__n(26),tan:__n(27),pow:function(a,b){return a**b},
PI:3.141592653589793,E:2.718281828459045,LN2:0.6931471805599453,LN10:2.302585092994046,LOG2E:1.4426950408889634,LOG10E:0.4342944819032518,SQRT2:1.4142135623730951,SQRT1_2:0.7071067811865476};
function isNaN(x){x=+x;return x!==x}function isFinite(x){x=+x;return x-x===0}
function parseInt(s,r){s=(''+s).trim();var i=0,g=1,l=s.length,c=s.charCodeAt(0);if(c===45){g=-1;i=1}else if(c===43)i=1;r=r|0;
if((r===0||r===16)&&s.charCodeAt(i)===48&&(s.charCodeAt(i+1)|32)===120){i+=2;r=16}if(r===0)r=10;var v=0,k=i;
while(i<l){c=s.charCodeAt(i);var d=c>=48&&c<=57?c-48:(c|32)>=97&&(c|32)<=122?(c|32)-87:99;if(d>=r)break;v=v*r+d;i++}return i===k?0/0:g*v}
function parseFloat(s){s=(''+s).trim();var i=0,c=s.charCodeAt(0);if(c===45||c===43)i=1;if(s.substring(i,i+8)==='Infinity')return c===45?-1/0:1/0;
var d=0;while((c=s.charCodeAt(i))>=48&&c<=57){i++;d++}if(c===46){i++;while((c=s.charCodeAt(i))>=48&&c<=57){i++;d++}}if(!d)return 0/0;
if((c|32)===101){var j=i+1,e=s.charCodeAt(j);if(e===45||e===43)j++;if((e=s.charCodeAt(j))>=48&&e<=57){while((e=s.charCodeAt(j))>=48&&e<=57)j++;i=j}}return +s.substring(0,i)}
(function(A,S,N,n){
function clamp(a,l,d){return a===undefined?d:a<0?(l+a>0?l+a:0):a>l?l:a}
function white(c){return c===32||(c>=9&&c<=13)||c===160||c===0xfeff||c===0x2028||c===0x2029}
Array.isArray=n(12);A.push=n(10);A.pop=n(11);
A.shift=function(){var l=this.length;if(!l)return;var v=this[0];for(var i=1;i<l;i++)this[i-1]=this[i];this.length=l-1;return v};
A.unshift=function(){var k=arguments.length,l=this.length,i;for(i=l-1;i>=0;i--)this[i+k]=this[i];for(i=0;i<k;i++)this[i]=arguments[i];return l+k};
A.indexOf=function(x,f){var l=this.length;for(var i=clamp(f,l,0);i<l;i++)if(this[i]===x)return i;return -1};
A.lastIndexOf=function(x){for(var i=this.length-1;i>=0;i--)if(this[i]===x)return i;return -1};
A.includes=function(x){var l=this.length;for(var i=0;i<l;i++){var v=this[i];if(v===x||(v!==v&&x!==x))return true}return false};
A.slice=function(a,b){var l=this.length,r=[];b=clamp(b,l,l);for(var i=clamp(a,l,0);i<b;i++)r.push(this[i]);return r};
A.concat=function(){var r=[],l=this.length,i;for(i=0;i<l;i++)r.push(this[i]);for(var j=0;j<arguments.length;j++){var x=arguments[j];if(Array.isArray(x))for(i=0;i<x.length;i++)r.push(x[i]);else r.push(x)}return r};
A.reverse=function(){var i=0,j=this.length-1;while(i<j){var t=this[i];this[i]=this[j];this[j]=t;i++;j--}return this};
A.join=function(s){if(s===undefined)s=',';var r='',l=this.length;for(var i=0;i<l;i++){if(i)r+=s;var v=this[i];if(v!==undefined&&v!==null)r+=v}return r};
A.toString=function(){return this.join()};
A.forEach=function(f){var l=this.length;for(var i=0;i<l;i++)f(this[i],i,this)};
A.map=function(f){var l=this.length,r=[];for(var i=0;i<l;i++)r.push(f(this[i],i,this));return r};
A.filter=function(f){var l=this.length,r=[];for(var i=0;i<l;i++){var v=this[i];if(f(v,i,this))r.push(v)}return r};
A.reduce=function(f,a){var l=this.length,i=0;if(arguments.length<2){if(!l)throw new TypeError('Reduce of empty array with no initial value');a=this[0];i=1}while(i<l){a=f(a,this[i],i,this);i++}return a};
A.reduceRight=function(f,a){var i=this.length-1;if(arguments.length<2){if(i<0)throw new TypeError('Reduce of empty array with no initial value');a=this[i];i--}while(i>=0){a=f(a,this[i],i,this);i--}return a};
A.some=function(f){var l=this.length;for(var i=0;i<l;i++)if(f(this[i],i,this))return true;return false};
A.every=function(f){var l=this.length;for(var i=0;i<l;i++)if(!f(this[i],i,this))return false;return true};
A.find=function(f){var l=this.length;for(var i=0;i<l;i++){var v=this[i];if(f(v,i,this))return v}};
A.findIndex=function(f){var l=this.length;for(var i=0;i<l;i++)if(f(this[i],i,this))return i;return -1};
A.fill=function(v){var l=this.length;for(var i=0;i<l;i++)this[i]=v;return this};
A.splice=function(s,d){var l=this.length,r=[],t=[],i;s=clamp(s,l,0);if(arguments.length<2||d>l-s)d=l-s;if(d<0)d=0;for(i=0;i<d;i++)r.push(this[s+i]);for(i=s+d;i<l;i++)t.push(this[i]);
this.length=s;for(i=2;i<arguments.length;i++)this.push(arguments[i]);for(i=0;i<t.length;i++)this.push(t[i]);return r};
A.sort=function(c){var a=this,n=a.length,b=[],w,i,j,k,m,e,lo;if(!c)c=function(x,y){x=''+x;y=''+y;return x<y?-1:x>y?1:0};
for(w=1;w<n;w*=2){for(lo=0;lo<n;lo+=2*w){m=lo+w<n?lo+w:n;e=lo+2*w<n?lo+2*w:n;i=lo;j=m;k=lo;while(i<m&&j<e){if(c(a[j],a[i])<0){b[k]=a[j];j++}else{b[k]=a[i];i++}k++}
while(i<m){b[k]=a[i];k++;i++}while(j<e){b[k]=a[j];k++;j++}}for(i=0;i<n;i++)a[i]=b[i]}return a};
S.charCodeAt=n(15);S.substring=n(17);S.toUpperCase=n(18);S.toLowerCase=n(19);S.toString=function(){return this};
String.fromCharCode=(function(f){return function(){var s='';for(var i=0;i<arguments.length;i++)s+=f(arguments[i]);return s}})(n(16));
S.charAt=function(i){i=i|0;return i<0?'':this.substring(i,i+1)};
S.indexOf=function(t,f){var s=''+this;t=''+t;var l=s.length,m=t.length;f=f>0?f|0:0;if(!m)return f<l?f:l;var c=t.charCodeAt(0);for(var i=f;i+m<=l;i++)if(s.charCodeAt(i)===c&&s.substring(i,i+m)===t)return i;return -1};
S.lastIndexOf=function(t){var s=''+this;t=''+t;var m=t.length;for(var i=s.length-m;i>=0;i--)if(s.substring(i,i+m)===t)return i;return -1};
S.includes=function(t,f){return this.indexOf(t,f)>=0};
S.startsWith=function(t,p){t=''+t;p=p>0?p|0:0;return this.substring(p,p+t.length)===t};
S.endsWith=function(t){t=''+t;var l=this.length;return l>=t.length&&this.substring(l-t.length,l)===t};
S.slice=function(a,b){var l=this.length;a=clamp(a,l,0);b=clamp(b,l,l);return a<b?this.substring(a,b):''};
S.substr=function(a,k){var l=this.length;a=clamp(a,l,0);if(k===undefined||k>l-a)k=l-a;return k>0?this.substring(a,a+k):''};
S.trim=function(){var s=''+this,a=0,b=s.length;while(a<b&&white(s.charCodeAt(a)))a++;while(b>a&&white(s.charCodeAt(b-1)))b--;return s.substring(a,b)};
S.trimStart=function(){var s=''+this,a=0,b=s.length;while(a<b&&white(s.charCodeAt(a)))a++;return s.substring(a,b)};
S.trimEnd=function(){var s=''+this,b=s.length;while(b>0&&white(s.charCodeAt(b-1)))b--;return s.substring(0,b)};
S.split=function(d){var s=''+this,r=[];if(d===undefined){r.push(s);return r}d=''+d;var l=s.length,k=d.length,i,p=0;if(!k){for(i=0;i<l;i++)r.push(s.substring(i,i+1));return r}
while((i=s.indexOf(d,p))>=0){r.push(s.substring(p,i));p=i+k}r.push(s.substring(p,l));return r};
S.repeat=function(k){var s=''+this,r='';while(k>0){if(k&1)r+=s;k>>=1;if(k)s+=s}return r};
S.padStart=function(k,p){var s=''+this,f='';p=p===undefined?' ':''+p;if(!p.length)return s;while(f.length+s.length<k)f+=p;return f.substring(0,k-s.length)+s};
S.padEnd=function(k,p){var s=''+this,f='';p=p===undefined?' ':''+p;if(!p.length)return s;while(f.length+s.length<k)f+=p;return s+f.substring(0,k-s.length)};
S.concat=function(){var s=''+this;for(var i=0;i<arguments.length;i++)s+=arguments[i];return s};
Function.prototype.call=n(28);Function.prototype.apply=n(29);
Function.prototype.bind=function(t){var f=this,a=[];for(var i=1;i<arguments.length;i++)a.push(arguments[i]);return function(){var b=a.slice();for(var i=0;i<arguments.length;i++)b.push(arguments[i]);return f.apply(t,b)}};
Object.prototype.toString=function(){return '[object Object]'};
Object.keys=n(13);Object.prototype.hasOwnProperty=n(14);
Object.values=function(o){var k=Object.keys(o),r=[];for(var i=0;i<k.length;i++)r.push(o[k[i]]);return r};
Object.entries=function(o){var k=Object.keys(o),r=[];for(var i=0;i<k.length;i++)r.push([k[i],o[k[i]]]);return r};
Object.assign=function(t){for(var i=1;i<arguments.length;i++){var s=arguments[i];if(s!==undefined&&s!==null){var k=Object.keys(s);for(var j=0;j<k.length;j++)t[k[j]]=s[k[j]]}}return t};
Number.isInteger=function(x){return typeof x==='number'&&x-x===0&&Math.floor(x)===x};
Number.isFinite=function(x){return typeof x==='number'&&x-x===0};
Number.isNaN=function(x){return x!==x};Number.parseFloat=parseFloat;Number.parseInt=parseInt;
Number.MAX_SAFE_INTEGER=9007199254740991;Number.MIN_SAFE_INTEGER=-9007199254740991;Number.EPSILON=2.220446049250313e-16;Number.MAX_VALUE=1.7976931348623157e308;Number.MIN_VALUE=5e-324;
N.toString=function(r){var x=+this;if(r===undefined||r===10)return ''+x;if(x!==x)return 'NaN';if(x-x!==0)return x<0?'-Infinity':'Infinity';var g=x<0?'-':'';if(x<0)x=-x;
var i=Math.floor(x),f=x-i,s='',D='0123456789abcdefghijklmnopqrstuvwxyz',d,c=0;do{d=i%r;s=D[d]+s;i=(i-d)/r}while(i>0);if(f>0){s+='.';while(f>0&&c<52){f*=r;d=Math.floor(f);s+=D[d];f-=d;c++}}return g+s};
// toFixed: exact. The number is taken apart into a whole number over a power of two; its decimal digits (lowest first) are
// moved up by the wanted places and halved that many times; the last halving's remainder says whether to round up.
N.toFixed=function(f){var x=+this,s,i,c,r=0,k=0,a=[];f=f|0;if(x!==x)return 'NaN';if(x>=1e21||x<=-1e21)return ''+x;var g=x<0?'-':'';if(x<0)x=-x;
if(x===Math.floor(x)){s=''+x;for(i=0;i<f;i++)s+='0'}else{while(x!==Math.floor(x)){x*=2;k++}while(x>0){c=x%10;a.push(c);x=(x-c)/10}for(i=0;i<f;i++)a.unshift(0);
while(k>0){r=0;for(i=a.length-1;i>=0;i--){c=r*10+a[i];a[i]=c>>1;r=c&1}k--}
if(r){i=0;while(1){if(i===a.length){a.push(1);break}a[i]=a[i]+1;if(a[i]<10)break;a[i]=0;i++}}
s='';for(i=a.length-1;i>=0;i--)s+=a[i];i=0;while(i<s.length-1&&s.charCodeAt(i)===48)i++;s=s.substring(i);while(s.length<=f)s='0'+s}
if(f)s=s.substring(0,s.length-f)+'.'+s.substring(s.length-f);return g+s};
})(Array.prototype,String.prototype,Number.prototype,__n);
