// The library's half that is written in the language (see lib.S). __n(k): the built-in routine numbered k.
__n(-7);
var __symobj;function Object(v){if(v===undefined||v===null)return {};if(typeof v==='symbol')return __symobj(v);return v}function Array(n){var a=[],i;if(arguments.length===1&&typeof n==='number'){if(n!==(n>>>0))throw new RangeError('Invalid array length');for(i=0;i<n;i++)a.push(undefined)}else for(i=0;i<arguments.length;i++)a.push(arguments[i]);return a}function Function(){}function String(x){if(!arguments.length)return '';if(typeof x==='symbol')return 'Symbol('+Symbol.__desc(x)+')';return ''+x}
function Number(x){return arguments.length?+x:0}function Boolean(x){return !!x}
__n(-1,Object.prototype);__n(-2,Array.prototype);__n(-3,Function.prototype);__n(-4,String.prototype);__n(-5,Number.prototype);__n(-6,Boolean.prototype);
var Math={floor:__n(1),ceil:__n(2),abs:__n(3),sqrt:__n(4),round:__n(5),trunc:__n(6),sign:__n(7),min:__n(8),max:__n(9),exp:__n(20),log:__n(21),log2:__n(22),log10:__n(23),random:__n(24),sin:__n(25),cos:__n(26),tan:__n(27),atan:__n(31),atan2:__n(32),asin:__n(33),acos:__n(34),expm1:__n(35),log1p:__n(36),sinh:__n(37),cosh:__n(38),tanh:__n(39),cbrt:__n(40),hypot:__n(41),asinh:__n(43),acosh:__n(44),atanh:__n(45),fround:__n(46),clz32:__n(47),imul:__n(48),pow:function(a,b){return a**b},
PI:3.141592653589793,E:2.718281828459045,LN2:0.6931471805599453,LN10:2.302585092994046,LOG2E:1.4426950408889634,LOG10E:0.4342944819032518,SQRT2:1.4142135623730951,SQRT1_2:0.7071067811865476};
var JSON={};
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
__n(-9,A.join);__n(-10,A.indexOf);__n(-11,A.slice);A.join=__n(49);A.indexOf=__n(50);A.slice=__n(51);
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
Object.keys=n(13);
function quote(s){var r='"',i=0,l=s.length,a=0,c;while(i<l){c=s.charCodeAt(i);if(c<32||c===34||c===92){r+=s.substring(a,i);a=i+1;
r+=c===34?'\\"':c===92?'\\\\':c===10?'\\n':c===13?'\\r':c===9?'\\t':c===8?'\\b':c===12?'\\f':'\\u00'+(c<16?'0':'')+c.toString(16)}i++}return r+s.substring(a,l)+'"'}
function str(k,h,rep,ind,gap){var v=h[k];if(v!==null&&v!==undefined&&typeof v.toJSON==='function')v=v.toJSON(k);if(rep)v=rep.call(h,k,v);
var t=typeof v;if(t==='string')return quote(v);if(t==='number')return v-v===0?''+v:'null';if(t==='boolean')return ''+v;if(v===null)return 'null';if(t!=='object')return;
var m=ind+gap,p=[],i,s;if(Array.isArray(v)){for(i=0;i<v.length;i++){s=str(i,v,rep,m,gap);p.push(s===undefined?'null':s)}
return p.length?(gap?'[\n'+m+p.join(',\n'+m)+'\n'+ind+']':'['+p.join(',')+']'):'[]'}
var ks=Object.keys(v);for(i=0;i<ks.length;i++){s=str(ks[i],v,rep,m,gap);if(s!==undefined)p.push(quote(ks[i])+(gap?': ':':')+s)}
return p.length?(gap?'{\n'+m+p.join(',\n'+m)+'\n'+ind+'}':'{'+p.join(',')+'}'):'{}'}
function walk(h,k,r){var v=h[k];if(v!==null&&typeof v==='object'){var ks=Object.keys(v);for(var i=0;i<ks.length;i++){var x=walk(v,ks[i],r);if(x===undefined)delete v[ks[i]];else v[ks[i]]=x}}return r.call(h,k,v)}
JSON.parse=(function(p){return function(s,r){var v=p(s);return typeof r==='function'?walk({'':v},'',r):v}})(n(30));
JSON.stringify=function(v,rep,sp){var gap='';if(typeof sp==='number'){if(sp>10)sp=10;while(gap.length<sp)gap+=' '}else if(typeof sp==='string')gap=sp.substring(0,10);
if(typeof rep!=='function')rep=null;return str('',{'':v},rep,'',gap)};Object.prototype.hasOwnProperty=n(14);
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
var Symbol={iterator:'\x01Symbol.iterator',asyncIterator:'\x01Symbol.asyncIterator'},Map,Set,WeakMap,WeakSet,WeakRef,FinalizationRegistry;
(function(n,A){
var id=n(42),D={};
function AI(a,m){this.a=a;this.i=0;this.m=m}
AI.prototype.next=function(){var a=this.a,i=this.i,m=this.m;if(i>=a.length)return{value:undefined,done:true};this.i=i+1;return{value:m===0?a[i]:m===1?i:[i,a[i]],done:false}};
AI.prototype['\x01Symbol.iterator']=function(){return this};
A.values=A['\x01Symbol.iterator']=function(){return new AI(this,0)};A.keys=function(){return new AI(this,1)};A.entries=function(){return new AI(this,2)};
n(-8,function(o){var f,t,a,r;if(o==null||typeof(f=o['\x01Symbol.iterator'])!=='function')throw new TypeError('the value is not iterable');
t=f.call(o);if(Array.isArray(t))return t;if(t instanceof AI&&t.m===0&&t.i===0){t.i=t.a.length;return t.a}a=[];while(!(r=t.next()).done)a.push(r.value);return a});
function key(k){var t=typeof k;return t==='string'?'s'+k:t==='number'?'n'+k:(t==='object'&&k!==null)||t==='function'?'o'+id(k):'x'+k}
function pack(m){var k=m._k,v=m._v,nk=[],nv=[],h={},i;for(i=0;i<k.length;i++)if(k[i]!==D){h[key(k[i])]=nk.length;nk.push(k[i]);if(v)nv.push(v[i])}m._k=nk;if(v)m._v=nv;m._h=h;m._d=0}
function list(m,w){var k=m._k,v=m._v,a=[],i;for(i=0;i<k.length;i++)if(k[i]!==D)a.push(w===0?k[i]:w===1?v[i]:w===2?[k[i],v[i]]:[k[i],k[i]]);return a}
function has(k){return this._h[key(k)]!==undefined}
function del(k){var s=key(k),i=this._h[s];if(i===undefined)return false;this._h[s]=undefined;this._k[i]=D;if(this._v)this._v[i]=undefined;this.size--;this._d++;if(this._d>32&&this._d>this.size)pack(this);return true}
Map=function Map(it){if(!(this instanceof Map))throw new TypeError("Constructor Map requires 'new'");this._h={};this._k=[];this._v=[];this.size=0;this._d=0;if(it!=null)for(var e of it)this.set(e[0],e[1])};
var M=Map.prototype;M.has=has;M['delete']=del;
M.get=function(k){var i=this._h[key(k)];return i===undefined?undefined:this._v[i]};
M.set=function(k,v){var s=key(k),i=this._h[s];if(i===undefined){this._h[s]=this._k.length;this._k.push(k===0?0:k);this._v.push(v);this.size++}else this._v[i]=v;return this};
M.clear=function(){this._h={};this._k=[];this._v=[];this.size=0;this._d=0};
M.forEach=function(f,t){var i;for(i=0;i<this._k.length;i++)if(this._k[i]!==D)f.call(t,this._v[i],this._k[i],this)};
M.keys=function(){return new AI(list(this,0),0)};M.values=function(){return new AI(list(this,1),0)};M.entries=M['\x01Symbol.iterator']=function(){return new AI(list(this,2),0)};
Set=function Set(it){if(!(this instanceof Set))throw new TypeError("Constructor Set requires 'new'");this._h={};this._k=[];this.size=0;this._d=0;if(it!=null)for(var e of it)this.add(e)};
var S=Set.prototype;S.has=has;S['delete']=del;
S.add=function(k){var s=key(k);if(this._h[s]===undefined){this._h[s]=this._k.length;this._k.push(k===0?0:k);this.size++}return this};
S.clear=function(){this._h={};this._k=[];this.size=0;this._d=0};
WeakMap=Map;WeakSet=Set;WeakRef=function WeakRef(o){this._o=o};FinalizationRegistry=function FinalizationRegistry(){};WeakRef.prototype.deref=function(){return this._o};FinalizationRegistry.prototype.register=FinalizationRegistry.prototype.unregister=function(){};
S.forEach=function(f,t){var i,k;for(i=0;i<this._k.length;i++)if((k=this._k[i])!==D)f.call(t,k,k,this)};
S.values=S.keys=S['\x01Symbol.iterator']=function(){return new AI(list(this,0),0)};S.entries=function(){return new AI(list(this,3),0)};
})(__n,Array.prototype);
var RegExp;
(function(n){var C=n(52),X=n(53);
RegExp=function RegExp(p,f){if(p instanceof RegExp){if(f===undefined)f=p.flags;p=p.source}if(!(this instanceof RegExp))return new RegExp(p,f);p=p===undefined||p===''?'(?:)':''+p;f=f===undefined?'':''+f;
this.source=p;this.flags=f;this.global=f.indexOf('g')>=0;this.ignoreCase=f.indexOf('i')>=0;this.multiline=f.indexOf('m')>=0;this.sticky=f.indexOf('y')>=0;this.dotAll=f.indexOf('s')>=0;this.unicode=f.indexOf('u')>=0;this.lastIndex=0;this._p=C(p,f)};
var R=RegExp.prototype;
R.exec=function(s){s=''+s;var g=this.global||this.sticky,i=g?this.lastIndex:0;if(i>s.length){this.lastIndex=0;return null}var c=X(this._p,s,i,this.sticky?1:0);if(c===null){if(g)this.lastIndex=0;return null}
var r=[],k;for(k=0;k<c.length;k+=2)r.push(c[k]<0?undefined:s.substring(c[k],c[k+1]));r.index=c[0];r.input=s;if(g)this.lastIndex=c[1];return r};
R.test=function(s){return this.exec(s)!==null};
R.toString=function(){return '/'+this.source+'/'+this.flags};
var S=String.prototype,osplit=S.split;
function all(r,s){var a=[],m;while((m=r.exec(s))!==null){a.push(m);if(m[0]==='')r.lastIndex++}return a}
function expand(t,m,s){var o='',i=0,n=t.length,c,d,e,k,p=m.index;while(i<n){c=t.charAt(i++);if(c!=='$'||i>=n){o+=c;continue}d=t.charAt(i);
if(d==='$'){o+='$';i++}else if(d==='&'){o+=m[0];i++}else if(d==='`'){o+=s.substring(0,p);i++}else if(d==="'"){o+=s.substring(p+m[0].length);i++}
else if(d>='0'&&d<='9'){k=+d;e=t.charAt(i+1);if(e!==''&&e>='0'&&e<='9'&&k*10+(+e)>0&&k*10+(+e)<m.length){k=k*10+(+e);i+=2}else if(k>0&&k<m.length)i++;else{o+='$';continue}if(m[k]!==undefined)o+=m[k]}
else o+='$'}return o}
function rep(s,m,f){if(typeof f==='function'){var a=m.slice(0);a.push(m.index,s);return ''+f.apply(undefined,a)}return expand(f,m,s)}
S.match=function(r){var s=''+this;if(!(r instanceof RegExp))r=new RegExp(r);if(!r.global)return r.exec(s);r.lastIndex=0;var a=all(r,s),i;if(!a.length)return null;for(i=0;i<a.length;i++)a[i]=a[i][0];return a};
S.matchAll=function(r){var s=''+this,l=0;if(r instanceof RegExp){if(!r.global)throw new TypeError('String.prototype.matchAll called with a non-global RegExp argument');l=r.lastIndex;r=new RegExp(r)}else r=new RegExp(r,'g');r.lastIndex=l;return all(r,s).values()};
S.search=function(r){if(!(r instanceof RegExp))r=new RegExp(r);var c=X(r._p,''+this,0,0);return c===null?-1:c[0]};
S.replace=function(r,f){var s=''+this,o='',p=0,a,i,m;if(typeof f!=='function')f=''+f;
if(r instanceof RegExp){if(r.global){r.lastIndex=0;a=all(r,s)}else{m=r.exec(s);a=m?[m]:[]}}else{r=''+r;i=s.indexOf(r);a=[];if(i>=0){m=[r];m.index=i;a.push(m)}}
for(i=0;i<a.length;i++){m=a[i];o+=s.substring(p,m.index)+rep(s,m,f);p=m.index+m[0].length}return o+s.substring(p)};
S.replaceAll=function(r,f){var s=''+this;if(r instanceof RegExp){if(!r.global)throw new TypeError('replaceAll must be called with a global RegExp');return s.replace(r,f)}
r=''+r;if(typeof f!=='function')f=''+f;var o='',p=0,q=0,i,m,k=r.length;while((i=s.indexOf(r,q))>=0){m=[r];m.index=i;o+=s.substring(p,i)+rep(s,m,f);p=i+k;q=p+(k?0:1);if(q>s.length)break}return o+s.substring(p)};
S.split=function(d,n){if(!(d instanceof RegExp))return n===undefined?osplit.call(this,d):osplit.call(this,d).slice(0,n>>>0);
var s=''+this,r=[],l=s.length,p=0,q=0,c,k;n=n===undefined?4294967295:n>>>0;if(!n)return r;if(!l){if(X(d._p,s,0,1)===null)r.push(s);return r}
while(q<l){c=X(d._p,s,q,1);if(c===null||c[1]===p){q++;continue}r.push(s.substring(p,q));if(r.length===n)return r;
for(k=2;k<c.length;k+=2){r.push(c[k]<0?undefined:s.substring(c[k],c[k+1]));if(r.length===n)return r}p=q=c[1]}r.push(s.substring(p));return r};
})(__n);
var Date;
(function(n){var now=n(54),D0=n(55),CV=n(56),F=Math.floor;
var WD=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],MN=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
function tz(){return now(1)*6e4}
function int(x){x=+x;return x!==x||x===1/0||x===-1/0?NaN:x<0?Math.ceil(x):F(x)}
function clip(t){return t!==t||t>8.64e15||t<-8.64e15?NaN:int(t)+0}
function mk(p){var i,s=0;for(i=0;i<7;i++){p[i]=int(p[i]);s+=p[i]}if(s!==s||p[0]>4e5||p[0]<-4e5||p[1]>5e6||p[1]<-5e6)return NaN;return (D0(p[0],p[1])+p[2]-1)*864e5+p[3]*36e5+p[4]*6e4+p[5]*1e3+p[6]}
function parts(t){var dy=F(t/864e5),r=t-dy*864e5,v=CV(dy),ym=F(v/32),w=dy+4-F((dy+4)/7)*7;return [F(ym/12),ym-F(ym/12)*12,v-ym*32,F(r/36e5),F(r/6e4)%60,F(r/1e3)%60,r%1e3,w]}
function p2(x,k){x=''+x;while(x.length<(k||2))x='0'+x;return x}
function yr(y){return y<0?'-'+p2(-y,6):p2(y,4)}
var ISO=/^([+-]\d{6}|\d{4})(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d):(\d\d)(?::(\d\d)(?:[.,](\d+))?)?)?(Z|[+-]\d\d:\d\d)?$/;
var LOOSE=/^(?:[A-Za-z]{3,},?\s+)?(?:([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2}),?|(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?,?)\s+(\d{1,6})(?:\s+(\d{1,2}):(\d\d)(?::(\d\d))?)?\s*(?:(?:GMT|UTC)?([+-]\d\d):?(\d\d)|(GMT|UTC|Z))?(?:\s*\(.*\))?$/;
var US=/^(\d{1,2})\/(\d{1,2})\/(\d{4})(?:,?\s+(\d{1,2}):(\d\d)(?::(\d\d))?)?$/;
function off(s,h,m){var z=(+h)*60+(+m);return (s==='-'?-z:z)*6e4}
function parse(s){s=(''+s).trim();var m=ISO.exec(s),t,k;
if(m){var mo=m[2]?+m[2]:1,d=m[3]?+m[3]:1,h=m[4]?+m[4]:0,mi=m[5]?+m[5]:0,sc=m[6]?+m[6]:0,ms=m[7]?+(m[7]+'00').substring(0,3):0;
if(mo<1||mo>12||d<1||d>31||h>24||mi>59||sc>59||(h===24&&(mi||sc||ms))||m[1]==='-000000')return NaN;t=mk([+m[1],mo-1,d,h,mi,sc,ms]);
if(m[8]){if(m[8]!=='Z')t-=off(m[8].charAt(0),m[8].substring(1,3),m[8].substring(4,6))}else if(m[4])t-=tz();return clip(t)}
if(m=LOOSE.exec(s)){k=m[1]||m[4];k=MN.indexOf(k.charAt(0).toUpperCase()+k.substring(1,3).toLowerCase());if(k<0)return NaN;
t=mk([+m[5],k,+(m[2]||m[3]),m[6]?+m[6]:0,m[7]?+m[7]:0,m[8]?+m[8]:0,0]);if(m[9])t-=off(m[9].charAt(0),m[9].substring(1),m[10]);else if(!m[11])t-=tz();return clip(t)}
if(m=US.exec(s))return clip(mk([+m[3],+m[1]-1,+m[2],m[4]?+m[4]:0,m[5]?+m[5]:0,m[6]?+m[6]:0,0])-tz());return NaN}
function fields(a){var p=[a[0],a.length>1?a[1]:0,1,0,0,0,0],i,y;for(i=2;i<a.length&&i<7;i++)p[i]=a[i];y=int(p[0]);if(y>=0&&y<=99)p[0]=1900+y;return mk(p)}
Date=function Date(y){var a=arguments,c=a.length,t;if(!(this instanceof Date))return new Date().toString();
if(c===0)t=now(0);else if(c===1)t=y instanceof Date?y._t:typeof y==='string'?parse(y):+y;else t=fields(a)-tz();this._t=clip(t)};
Date.now=function(){return now(0)};Date.parse=parse;Date.UTC=function(){return clip(fields(arguments))};
var P=Date.prototype,G=['FullYear','Month','Date','Hours','Minutes','Seconds','Milliseconds','Day'],i;
function getter(i,u){return function(){var t=this._t;return t!==t?NaN:parts(u?t:t+tz())[i]}}
function setter(i,u){return function(){var a=arguments,t=this._t,z=u?0:tz(),p,k,mx=i<3?3-i:7-i;if(t!==t){if(i)return NaN;p=parts(0)}else p=parts(t+z);
if(!a.length)p[i]=NaN;for(k=0;k<a.length&&k<mx;k++)p[i+k]=+a[k];return this._t=clip(mk(p)-z)}}
for(i=0;i<8;i++){P['get'+G[i]]=getter(i,0);P['getUTC'+G[i]]=getter(i,1);if(i<7){P['set'+G[i]]=setter(i,0);P['setUTC'+G[i]]=setter(i,1)}}
P.getTime=P.valueOf=function(){return this._t};P.setTime=function(t){return this._t=clip(+t)};
P.getTimezoneOffset=function(){return this._t!==this._t?NaN:-now(1)};P.getYear=function(){return this.getFullYear()-1900};
function iso(t){var p=parts(t),y=p[0];return (y>=0&&y<=9999?p2(y,4):(y<0?'-':'+')+p2(y<0?-y:y,6))+'-'+p2(p[1]+1)+'-'+p2(p[2])+'T'+p2(p[3])+':'+p2(p[4])+':'+p2(p[5])+'.'+p2(p[6],3)+'Z'}
P.toISOString=function(){if(this._t!==this._t)throw new RangeError('Invalid time value');return iso(this._t)};
P.toJSON=function(){return this._t!==this._t?null:iso(this._t)};
function zone(){var o=now(1),a=o<0?-o:o;return 'GMT'+(o<0?'-':'+')+p2(F(a/60))+p2(a%60)+(o?'':' (Coordinated Universal Time)')}
function ds(p){return WD[p[7]]+' '+MN[p[1]]+' '+p2(p[2])+' '+yr(p[0])}
function ts(p){return p2(p[3])+':'+p2(p[4])+':'+p2(p[5])}
function lt(p){var h=p[3]%12;return (h?h:12)+':'+p2(p[4])+':'+p2(p[5])+' '+(p[3]<12?'AM':'PM')}
function fmt(k){return function(){var t=this._t;if(t!==t)return 'Invalid Date';var p=parts(k===3?t:t+tz());
return k===0?ds(p)+' '+ts(p)+' '+zone():k===1?ds(p):k===2?ts(p)+' '+zone():k===3?WD[p[7]]+', '+p2(p[2])+' '+MN[p[1]]+' '+yr(p[0])+' '+ts(p)+' GMT':k===4?(p[1]+1)+'/'+p[2]+'/'+p[0]:k===5?lt(p):(p[1]+1)+'/'+p[2]+'/'+p[0]+', '+lt(p)}}
P.toString=P['\x01Symbol.toPrimitive']=fmt(0);P.toDateString=fmt(1);P.toTimeString=fmt(2);P.toUTCString=P.toGMTString=fmt(3);P.toLocaleDateString=fmt(4);P.toLocaleTimeString=fmt(5);P.toLocaleString=fmt(6);
})(__n);
var __q;if(!__q)__q={m:[],t:[],id:0};
var Promise,setTimeout,setInterval,clearTimeout,clearInterval,queueMicrotask,__jobs;
(function(n,Q){var now=n(54),setclock=n(57),setwake=n(58),F=Math.floor;
function P(ex){if(!(this instanceof P))throw new TypeError("Promise constructor cannot be invoked without 'new'");if(typeof ex!=='function')throw new TypeError('Promise resolver '+ex+' is not a function');
this._s=0;this._v=undefined;this._r=[];var p=this,done=false;
try{ex(function(v){if(!done){done=true;res(p,v)}},function(e){if(!done){done=true;settle(p,2,e)}})}catch(e){if(!done){done=true;settle(p,2,e)}}}
function res(p,v){if(v===p)return settle(p,2,new TypeError('Chaining cycle detected for promise #<Promise>'));
if(v!==null&&(typeof v==='object'||typeof v==='function')){var o={},th,done=false;gt(v,o);th=o.t;if(o.b)return settle(p,2,th);
if(typeof th==='function'){Q.m.push(function(){try{th.call(v,function(x){if(!done){done=true;res(p,x)}},function(e){if(!done){done=true;settle(p,2,e)}})}catch(e){if(!done){done=true;settle(p,2,e)}}});return}}
settle(p,1,v)}
function settle(p,s,v){if(p._s)return;p._s=s;p._v=v;var r=p._r,i;p._r=null;for(i=0;i<r.length;i++)react(p,r[i])}
function react(p,r){Q.m.push(function(){var h=p._s===1?r.f:r.r,x;if(typeof h!=='function'){if(p._s===1)res(r.p,p._v);else settle(r.p,2,p._v);return}try{x=h(p._v)}catch(e){settle(r.p,2,e);return}res(r.p,x)})}
function nop(){}
function gt(v,o){try{o.t=v.then}catch(e){o.b=1;o.t=e}}
var R=P.prototype;
R.then=function(f,r){var q=new P(nop),e={f:f,r:r,p:q};if(this._s)react(this,e);else this._r.push(e);return q};
R['catch']=function(r){return this.then(undefined,r)};
R['finally']=function(f){if(typeof f!=='function')return this.then(f,f);return this.then(function(v){return P.resolve(f()).then(function(){return v})},function(e){return P.resolve(f()).then(function(){throw e})})};
P.resolve=function(v){if(v instanceof P)return v;return new P(function(a){a(v)})};
P.reject=function(e){return new P(function(a,b){b(e)})};
function each(it,one,end){var k=0;for(var x of it)one(P.resolve(x),k++);end(k)}
P.all=function(it){return new P(function(ok,no){var out=[],n=0;each(it,function(p,k){out.push(undefined);n++;p.then(function(v){out[k]=v;if(--n===0)ok(out)},no)},function(k){if(!k)ok(out)})})};
P.allSettled=function(it){return new P(function(ok){var out=[],n=0;function put(k,o){out[k]=o;if(--n===0)ok(out)}
each(it,function(p,k){out.push(undefined);n++;p.then(function(v){put(k,{status:'fulfilled',value:v})},function(e){put(k,{status:'rejected',reason:e})})},function(k){if(!k)ok(out)})})};
P.race=function(it){return new P(function(ok,no){each(it,function(p){p.then(ok,no)},nop)})};
P.any=function(it){return new P(function(ok,no){var errs=[],n=0;function fail(){var e=new Error('All promises were rejected');e.name='AggregateError';e.errors=errs;no(e)}
each(it,function(p,k){errs.push(undefined);n++;p.then(ok,function(e){errs[k]=e;if(--n===0)fail()})},function(k){if(!k)fail()})})};
Promise=P;
function rest(a){var r=[],i;for(i=2;i<a.length;i++)r.push(a[i]);return r}
function add(f,ms,a,ev){ms=+ms;ms=ms>=1&&ms<=2147483647?F(ms):1;var t={id:++Q.id,at:now(0)+ms,f:f,a:a,ev:ev?ms:0};Q.t.push(t);return t.id}
setTimeout=function(f,ms){return add(f,ms,rest(arguments),0)};setInterval=function(f,ms){return add(f,ms,rest(arguments),1)};
clearTimeout=clearInterval=function(id){var T=Q.t,i;for(i=0;i<T.length;i++)if(T[i].id===id){T.splice(i,1);return}};
queueMicrotask=function(f){Q.m.push(f)};
function micro(){var i=0;while(i<Q.m.length)Q.m[i++]();Q.m=[]}
function run1(){var T=Q.t,i,b=-1,t;for(i=0;i<T.length;i++)if(b<0||T[i].at<T[b].at)b=i;if(b<0)return false;t=T[b];
if(t.at>now(0)){if(now(2))return false;setclock(t.at)}T.splice(b,1);if(t.ev){t.at=(now(2)?now(0):t.at)+t.ev;T.push(t)}
if(typeof t.f==='function')t.f.apply(undefined,t.a);micro();return true}
__jobs=function(){micro();var k=0,T,i,b=-1;while(run1()&&++k<1e5);T=Q.t;for(i=0;i<T.length;i++)if(b<0||T[i].at<b)b=T[i].at;setwake(b)};
})(__n,__q);
(function(n){var rs=n(59),RT={},GP={next:function(v){return st(this,0,v)},'return':function(v){return st(this,2,v)},'throw':function(e){return st(this,1,e)}};
GP['\x01Symbol.iterator']=function(){return this};
function st(g,m,v){if(g._r)throw new TypeError('Generator is already running');
if(g._d||(m&&!g._s)){g._d=true;if(m===1)throw v;return{value:m?v:undefined,done:true}}
var h=g._h,r;g._r=g._s=true;h[1]=0;
try{r=rs(h,m?1:null,m===2?RT:v)}catch(e){g._r=false;g._d=true;if(e===RT)return{value:v,done:true};throw e}
g._r=false;if(h[1])return{value:r,done:false};g._d=true;return{value:r,done:true}}
function G(h){this._h=h;this._r=this._s=this._d=false}G.prototype=GP;n(-12,function(h){return new G(h)});
n(-13,function(h){return new Promise(function(res,rej){
function step(m,v){var r;h[1]=0;try{r=rs(h,m,v)}catch(e){rej(e);return}
if(!h[1]){res(r);return}
Promise.resolve(r).then(function(x){step(null,x)},function(e){step(1,e)})}
step(null)})})})(__n);
var __host=(function(n){var h=n(60),a=n(61);return function(r){h(''+r);return a()}})(__n);
var globalThis=__n(62)();
var console=(function(){var p=function(){__console.log(...arguments)},z=function(){};return {log:p,info:p,warn:p,error:p,debug:p,trace:p,table:p,group:p,groupCollapsed:p,groupEnd:z,time:z,timeEnd:z,count:z,assert:function(c){if(!c)p('Assertion failed')}}})();
(function(n){var acc=n(63),gp=n(64),sp=n(65),own=Object.prototype.hasOwnProperty,same=function(o){return o};
Object.defineProperty=function(o,k,d){if(d&&(d.get||d.set))acc(o,k,d.get,d.set);else if(d&&'value' in d)o[k]=d.value;else if(!own.call(o,k))o[k]=undefined;return o};
Object.defineProperties=function(o,ds){for(var k in ds)if(own.call(ds,k))Object.defineProperty(o,k,ds[k]);return o};
Object.getPrototypeOf=function(o){var t=typeof o;return t=='string'?String.prototype:t=='number'?Number.prototype:t=='boolean'?Boolean.prototype:gp(o)};
Object.setPrototypeOf=function(o,p){sp(o,p);return o};
Object.create=function(p,ds){var o={};sp(o,p);if(ds)Object.defineProperties(o,ds);return o};
Object.freeze=same;Object.seal=same;Object.preventExtensions=same;Object.isFrozen=function(){return false};Object.isSealed=function(){return false};Object.isExtensible=function(){return true};
Object.getOwnPropertyNames=function(o){return Object.keys(o)};Object.getOwnPropertySymbols=function(){return []};
Object.getOwnPropertyDescriptor=function(o,k){return own.call(o,k)?{value:o[k],writable:true,enumerable:true,configurable:true}:undefined};
Object.is=function(a,b){return a===b?a!==0||1/a===1/b:a!==a&&b!==b};
Object.fromEntries=function(it){var o={};for(var e of it)o[e[0]]=e[1];return o};
})(__n);
var encodeURIComponent,encodeURI,decodeURIComponent,decodeURI;
(function(){var hex='0123456789ABCDEF',bad=function(){throw new (typeof URIError=='function'?URIError:Error)('URI malformed')};
function enc(s,keep){s=String(s);var r='';for(var i=0;i<s.length;i++){var c=s.charCodeAt(i);
if(c<128){var ch=s.charAt(i);if(c>=48&&c<58||c>=65&&c<91||c>=97&&c<123||keep.indexOf(ch)>=0){r+=ch;continue}}
if(c>=0xdc00&&c<0xe000)bad();if(c>=0xd800&&c<0xdc00){var d=i+1<s.length?s.charCodeAt(i+1):0;if(d>=0xdc00&&d<0xe000){c=0x10000+((c-0xd800)<<10)+(d-0xdc00);i++}else bad()}
var b=c<128?[c]:c<0x800?[0xc0|c>>6,0x80|c&63]:c<0x10000?[0xe0|c>>12,0x80|c>>6&63,0x80|c&63]:[0xf0|c>>18,0x80|c>>12&63,0x80|c>>6&63,0x80|c&63];
for(var j=0;j<b.length;j++)r+='%'+hex.charAt(b[j]>>4)+hex.charAt(b[j]&15)}return r}
function dec(s,keep){s=String(s);var r='';for(var i=0;i<s.length;i++){var ch=s.charAt(i);if(ch!='%'){r+=ch;continue}
var b=parseInt(s.substr(i+1,2),16);if(!(b>=0)||s.length<i+3)bad();var n=b<128?0:b>=0xf0?3:b>=0xe0?2:b>=0xc0?1:-1;if(n<0)bad();var c=n==0?b:b&(0x3f>>n),start=i;i+=2;
for(var j=0;j<n;j++){if(s.charAt(i+1)!='%')bad();var t=parseInt(s.substr(i+2,2),16);if((t&0xc0)!=0x80)bad();c=c<<6|t&63;i+=3}
var out=String.fromCodePoint(c);if(n==0&&keep.indexOf(out)>=0)out=s.substr(start,3);r+=out}return r}
encodeURIComponent=function(s){return enc(s,"-_.!~*'()")};encodeURI=function(s){return enc(s,"-_.!~*'();/?:@&=+$,#")};
decodeURIComponent=function(s){return dec(s,'')};decodeURI=function(s){return dec(s,';/?:@&=+$,#')};
})();
String.fromCodePoint=function(){var r='';for(var i=0;i<arguments.length;i++){var c=+arguments[i];if(!(c>=0&&c<=0x10ffff)||c!==Math.floor(c))throw new RangeError('Invalid code point '+arguments[i]);r+=c<0x10000?String.fromCharCode(c):String.fromCharCode(0xd800+((c-0x10000)>>10),0xdc00+((c-0x10000)&1023))}return r};
String.prototype.codePointAt=function(i){i=i|0;var s=String(this);if(i<0||i>=s.length)return undefined;var c=s.charCodeAt(i);if(c>=0xd800&&c<0xdc00&&i+1<s.length){var d=s.charCodeAt(i+1);if(d>=0xdc00&&d<0xe000)return 0x10000+((c-0xd800)<<10)+(d-0xdc00)}return c};
var __spread=Object.assign;
var __rest=function(v){var o={},ks=Object.keys(v),n=arguments.length,i,j,k;for(i=0;i<ks.length;i++){k=ks[i];for(j=1;j<n&&arguments[j]!==k;j++);if(j>=n)o[k]=v[k]}return o};
var __import=function(u){return Promise.reject(new TypeError('import() is not made yet: '+u))};__import.meta={url:''};
Object.prototype.propertyIsEnumerable=function(k){return Object.prototype.hasOwnProperty.call(this,k)};
Object.prototype.isPrototypeOf=function(o){if(o==null)return false;for(o=Object.getPrototypeOf(o);o!=null;o=Object.getPrototypeOf(o))if(o===this)return true;return false};
Object.getOwnPropertySymbols=function(){return[]};
(function(){var old=Symbol,n=0,reg={},k,
S=function Symbol(d){if(this instanceof S)throw new TypeError('Symbol is not a constructor');return '\x01'+(d===undefined?'':String(d))+'\x01'+(++n)},
w=['hasInstance','toPrimitive','toStringTag','species','unscopables','match','matchAll','replace','search','split','isConcatSpreadable'];
// a symbol is a string whose first unit is \x01 (typeof says "symbol"): \x01 description \x01 number, or \x01Symbol.name for the well-known ones
for(k in old)S[k]=old[k];for(k=0;k<w.length;k++)S[w[k]]='\x01Symbol.'+w[k];
S['for']=function(k){k=String(k);return reg[k]||(reg[k]=S(k))};S.keyFor=function(s){for(var k in reg)if(reg[k]===s)return k};
var desc=function(s){var i=s.lastIndexOf('\x01');return i>0?s.slice(1,i):s.slice(1)};S.__desc=desc;
S.prototype={constructor:S,toString:function(){return 'Symbol('+desc(this.__s)+')'},valueOf:function(){return this.__s}};
Object.defineProperty(S.prototype,'description',{get:function(){return desc(this.__s)}});
__symobj=function(v){var o=Object.create(S.prototype);o.__s=v;return o};
Symbol=S})();
Array.from=function(it,f,t){var r=[],i=0,v,n;if(it==null)throw new TypeError(it+' is not iterable');
if(typeof it[Symbol.iterator]==='function'){for(v of it){r.push(f?f.call(t,v,i):v);i++}return r}
n=it.length>>>0;for(;i<n;i++){v=it[i];r.push(f?f.call(t,v,i):v)}return r};
Array.of=function(){return Array.prototype.slice.call(arguments)};
(function(){var T=Symbol.toStringTag,isA=Array.isArray;
Math[T]='Math';JSON[T]='JSON';Map.prototype[T]='Map';Set.prototype[T]='Set';Promise.prototype[T]='Promise';Symbol.prototype[T]='Symbol';
Object.prototype.toString=function(){var o=this,t=typeof o,g;if(o===undefined)return '[object Undefined]';if(o===null)return '[object Null]';
if(t==='number')return '[object Number]';if(t==='string')return '[object String]';if(t==='boolean')return '[object Boolean]';if(t==='symbol')return '[object Symbol]';
g=o[T];if(typeof g==='string')return '[object '+g+']';if(t==='function')return '[object Function]';if(isA(o))return '[object Array]';
if(o instanceof Date)return '[object Date]';if(o instanceof RegExp)return '[object RegExp]';if(o instanceof Error)return '[object Error]';return '[object Object]'}})();
