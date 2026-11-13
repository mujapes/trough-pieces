// What a page's scripts see: document, elements, window. Written in the language over the dom piece (dom/intent.md);
// every answer comes from the tree, nothing about the page is kept here except one object per node.
var __d=function(s){var r=__host('d'+s);if(r==='\u0001E')throw new Error('the page tree refused: '+s.slice(0,40));return r};
var __nodes={},__texts={};
function __w(n){n=+n;if(!n)return null;var o=__nodes[n];if(!o){var k=+__d('k'+n);o=k==1?new(__tagc[__d('n'+n)]||Element)(n):k==9?new Document(n):new Node(n,k);__nodes[n]=o}return o}
function __list(s){var r=[];if(s){var p=s.split(' ');for(var i=0;i<p.length;i++)r.push(__w(p[i]))}r.item=function(i){return this[i]||null};return r}
class Event{constructor(t,o){this.type=t;this.bubbles=!!(o&&o.bubbles);this.defaultPrevented=false;this.target=null}
 initEvent(t,b){this.type=t;this.bubbles=!!b}preventDefault(){this.defaultPrevented=true}stopPropagation(){this.__stop=true}stopImmediatePropagation(){this.__stop=true}}
var CustomEvent=Event;
class EventTarget{
 addEventListener(t,f){if(!f)return;var l=this.__l||(this.__l={});(l[t]||(l[t]=[])).push(f)}
 removeEventListener(t,f){var a=this.__l&&this.__l[t];if(a){var i=a.indexOf(f);if(i>=0)a.splice(i,1)}}
 dispatchEvent(e){if(!e.target)e.target=this;e.currentTarget=this;var a=this.__l&&this.__l[e.type];
  if(a){a=a.slice();for(var i=0;i<a.length;i++){try{if(typeof a[i]=='function')a[i].call(this,e);else a[i].handleEvent(e)}catch(x){console.log('in a '+e.type+' listener: '+x)}}}
  var h=this['on'+e.type];if(typeof h=='function'){try{h.call(this,e)}catch(x){console.log('in on'+e.type+': '+x)}}
  var p=e.bubbles&&!e.__stop?this.parentNode:null;if(p)p.dispatchEvent(e);return !e.defaultPrevented}
}
function __cmp(c){var r={tag:'',id:'',cls:[],at:[]},m,re=/^([#.]?)([\w-]+)|^\[\s*([\w-]+)\s*(?:([|^$*~]?=)\s*["']?([^"'\]]*)["']?\s*)?\]|^:[\w-]+(?:\([^)]*\))?|^\*/;
 while(c&&(m=re.exec(c))){if(m[2]){if(m[1]=='#')r.id=m[2];else if(m[1]=='.')r.cls.push(m[2]);else r.tag=m[2].toLowerCase()}else if(m[3])r.at.push([m[3],m[4]||'',m[5]||'']);c=c.slice(m[0].length)}
 return r}
function __is(e,r){if(r.tag&&__d('n'+e.__n)!=r.tag)return false;if(r.id&&e.getAttribute('id')!==r.id)return false;var i;
 if(r.cls.length){var c=' '+(e.getAttribute('class')||'').replace(/\s+/g,' ')+' ';for(i=0;i<r.cls.length;i++)if(c.indexOf(' '+r.cls[i]+' ')<0)return false}
 for(i=0;i<r.at.length;i++){var a=r.at[i],v=e.getAttribute(a[0]);if(v===null)return false;var o=a[1],w=a[2];
  if(o=='='&&v!==w)return false;if(o=='^='&&v.indexOf(w)!=0)return false;if(o=='*='&&v.indexOf(w)<0)return false;if(o=='$='&&v.slice(-w.length)!==w)return false;if(o=='~='&&(' '+v+' ').indexOf(' '+w+' ')<0)return false}
 return true}
function __chain(e,ch){var i=ch.length-2,p=e.parentNode;while(i>=0){while(p&&p.nodeType==1&&!__is(p,ch[i]))p=p.parentNode;if(!p||p.nodeType!=1)return false;p=p.parentNode;i--}return true}
function __split(s){var t=s.replace(/\s*[>+]\s*/g,' ').trim();return t?t.split(/\s+/).map(__cmp):null}
function __sel(root,s){var out=[],seen={},parts=String(s).split(',');
 for(var j=0;j<parts.length;j++){var ch=__split(parts[j]);if(!ch)continue;var last=ch[ch.length-1];
  var c=__list(__d('q'+root.__n+' '+(last.id?'#'+last.id:last.cls.length?'.'+last.cls[0]:last.tag||'*')));
  for(var i=0;i<c.length;i++){var e=c[i];if(!seen[e.__n]&&__is(e,last)&&__chain(e,ch)){seen[e.__n]=1;out.push(e)}}}
 out.item=function(i){return this[i]||null};return out}
class Node extends EventTarget{
 constructor(n,k){super();this.__n=n;this.nodeType=k}
 get nodeName(){var s=__d('n'+this.__n);return this.nodeType==1?s.toUpperCase():s}
 get parentNode(){return __w(__d('p'+this.__n))}
 get parentElement(){var p=this.parentNode;return p&&p.nodeType==1?p:null}
 get firstChild(){return __w(__d('f'+this.__n))}
 get lastChild(){return __w(__d('l'+this.__n))}
 get nextSibling(){return __w(__d('N'+this.__n))}
 get previousSibling(){return __w(__d('P'+this.__n))}
 get childNodes(){return __list(__d('L'+this.__n))}
 get children(){return __list(__d('E'+this.__n))}
 get firstElementChild(){return this.children[0]||null}
 get lastElementChild(){var c=this.children;return c[c.length-1]||null}
 get childElementCount(){return this.children.length}
 get nextElementSibling(){var n=this.nextSibling;while(n&&n.nodeType!=1)n=n.nextSibling;return n}
 get previousElementSibling(){var n=this.previousSibling;while(n&&n.nodeType!=1)n=n.previousSibling;return n}
 get textContent(){return __d('t'+this.__n)}
 set textContent(v){__d('T'+this.__n+' '+(v==null?'':v))}
 get nodeValue(){return this.nodeType==3||this.nodeType==8?__d('t'+this.__n):null}
 set nodeValue(v){if(this.nodeType==3||this.nodeType==8)this.textContent=v}
 get data(){return this.nodeValue}
 set data(v){this.nodeValue=v}
 get ownerDocument(){return document}
 get isConnected(){return document.contains(this)}
 hasChildNodes(){return !!this.firstChild}
 contains(o){while(o){if(o===this)return true;o=o.parentNode}return false}
 compareDocumentPosition(o){if(o===this)return 0;function up(n){var a=[];while(n){a.unshift(n);n=n.parentNode}return a}var A=up(this),B=up(o);if(A[0]!==B[0])return 1|32|2;var i=0;while(i<A.length&&i<B.length&&A[i]===B[i])i++;if(i===A.length)return 4|16;if(i===B.length)return 2|8;var k=Array.prototype.slice.call(A[i-1].childNodes);return k.indexOf(B[i])<k.indexOf(A[i])?2:4}
 appendChild(c){if(c.__frag){var k=c.childNodes;for(var i=0;i<k.length;i++)this.appendChild(k[i]);return c}__d('a'+this.__n+' '+c.__n);return c}
 insertBefore(c,r){if(!r)return this.appendChild(c);if(c.__frag){var k=c.childNodes;for(var i=0;i<k.length;i++)this.insertBefore(k[i],r);return c}__d('b'+this.__n+' '+c.__n+' '+r.__n);return c}
 removeChild(c){__d('r'+c.__n);return c}
 replaceChild(n,o){this.insertBefore(n,o);__d('r'+o.__n);return o}
 remove(){__d('r'+this.__n)}
 append(){for(var i=0;i<arguments.length;i++){var a=arguments[i];this.appendChild(typeof a=='string'?document.createTextNode(a):a)}}
 prepend(){var f=this.firstChild;for(var i=0;i<arguments.length;i++){var a=arguments[i];this.insertBefore(typeof a=='string'?document.createTextNode(a):a,f)}}
 cloneNode(deep){if(this.nodeType!=1)return document.createTextNode(this.textContent);var h=document.createElement('div');h.innerHTML=this.outerHTML;var r=h.firstChild;if(!deep)r.textContent='';r.remove();return r}
 getElementsByTagName(t){return __list(__d('q'+this.__n+' '+t))}
 getElementsByClassName(c){return __sel(this,'.'+String(c).trim().split(/\s+/).join('.'))}
 querySelectorAll(s){return __sel(this,s)}
 querySelector(s){return __sel(this,s)[0]||null}
}
class Element extends Node{
 constructor(n){if(n===undefined&&__upg){var p=__upg;__upg=null;return p}var made=n===undefined;if(made)n=+__d('c div');super(n,1);if(made)__nodes[n]=this}
 get tagName(){return __d('n'+this.__n).toUpperCase()}
 get localName(){return __d('n'+this.__n)}
 getAttribute(k){var s=__d('g'+this.__n+' '+k);return s.charAt(0)=='1'?s.slice(1):null}
 setAttribute(k,v){__d('s'+this.__n+' '+k+' '+v)}
 hasAttribute(k){return __d('g'+this.__n+' '+k).charAt(0)=='1'}
 removeAttribute(k){__d('u'+this.__n+' '+k)}
 toggleAttribute(k,f){var h=this.hasAttribute(k);if(f===undefined)f=!h;if(f&&!h)this.setAttribute(k,'');else if(!f&&h)this.removeAttribute(k);return !!f}
 getAttributeNames(){var r=[],a=this.attributes||[];for(var i=0;i<a.length;i++)r.push(a[i].name);return r}
 get id(){return this.getAttribute('id')||''}
 set id(v){this.setAttribute('id',v)}
 get className(){return this.getAttribute('class')||''}
 set className(v){this.setAttribute('class',v)}
 get href(){return this.getAttribute('href')||''}
 set href(v){this.setAttribute('href',v)}
 get src(){return this.getAttribute('src')||''}
 set src(v){this.setAttribute('src',v)}
 get value(){var v=this.getAttribute('value');return v===null?(this.localName=='textarea'?this.textContent:''):v}
 set value(v){this.setAttribute('value',v)}
 get type(){return this.getAttribute('type')||''}
 set type(v){this.setAttribute('type',v)}
 get name(){return this.getAttribute('name')||''}
 set name(v){this.setAttribute('name',v)}
 get title(){return this.getAttribute('title')||''}
 set title(v){this.setAttribute('title',v)}
 get alt(){return this.getAttribute('alt')||''}
 set alt(v){this.setAttribute('alt',v)}
 get lang(){return this.getAttribute('lang')||''}
 set lang(v){this.setAttribute('lang',v)}
 get dir(){return this.getAttribute('dir')||''}
 set dir(v){this.setAttribute('dir',v)}
 get hidden(){return this.hasAttribute('hidden')}
 set hidden(v){if(v)this.setAttribute('hidden','');else this.removeAttribute('hidden')}
 get disabled(){return this.hasAttribute('disabled')}
 set disabled(v){if(v)this.setAttribute('disabled','');else this.removeAttribute('disabled')}
 get checked(){return this.hasAttribute('checked')}
 set checked(v){if(v)this.setAttribute('checked','');else this.removeAttribute('checked')}
 get innerHTML(){return __d('h'+this.__n)}
 set innerHTML(v){__d('H'+this.__n+' '+(v==null?'':v))}
 get outerHTML(){return __d('o'+this.__n)}
 get innerText(){return this.textContent}
 set innerText(v){this.textContent=v}
 get style(){return this.__s||(this.__s={setProperty:function(k,v){this[k]=v},getPropertyValue:function(k){var v=this[k];return typeof v=='string'?v:''},removeProperty:function(k){this[k]=''}})}
 get dataset(){return this.__ds||(this.__ds={})}
 get classList(){var e=this,get=function(){return (e.getAttribute('class')||'').split(/\s+/).filter(function(x){return x})},put=function(a){e.setAttribute('class',a.join(' '))};
  return {contains:function(c){return get().indexOf(c)>=0},item:function(i){return get()[i]||null},toString:function(){return e.className},
   add:function(){var a=get();for(var i=0;i<arguments.length;i++)if(a.indexOf(arguments[i])<0)a.push(arguments[i]);put(a)},
   remove:function(){var a=get();for(var i=0;i<arguments.length;i++){var k=a.indexOf(arguments[i]);if(k>=0)a.splice(k,1)}put(a)},
   toggle:function(c,f){if(f===undefined)f=!this.contains(c);if(f)this.add(c);else this.remove(c);return !!f}}}
 matches(s){var p=String(s).split(',');for(var j=0;j<p.length;j++){var ch=__split(p[j]);if(ch&&__is(this,ch[ch.length-1])&&__chain(this,ch))return true}return false}
 attachShadow(o){var f=document.createDocumentFragment();f.host=this;f.mode=o&&o.mode;this.__shadow=f;if(!o||o.mode!=='closed')this.shadowRoot=f;return f}
 attachInternals(){var e=this;return {states:new Set(),setFormValue:function(){},setValidity:function(){},checkValidity:function(){return true},reportValidity:function(){return true},get form(){return e.closest('form')},role:null,ariaLabel:null,shadowRoot:e.__shadow||null}}
 get content(){if(String(this.tagName).toLowerCase()!=="template")return this.getAttribute("content");return this.__content||(this.__content=document.createDocumentFragment())}
 closest(s){var e=this;while(e&&e.nodeType==1){if(e.matches(s))return e;e=e.parentNode}return null}
 insertAdjacentHTML(pos,h){var t=document.createElement('div');t.innerHTML=h;var k=t.childNodes,p=String(pos).toLowerCase(),f=this.firstChild,n=this.nextSibling,up=this.parentNode;
  for(var i=0;i<k.length;i++){if(p=='beforeend')this.appendChild(k[i]);else if(p=='afterbegin')this.insertBefore(k[i],f);else if(up)up.insertBefore(k[i],p=='beforebegin'?this:n)}}
 getBoundingClientRect(){return {left:0,top:0,right:0,bottom:0,width:0,height:0,x:0,y:0}}
 focus(){}
 blur(){}
 scrollIntoView(){}
 click(){this.dispatchEvent(new Event('click',{bubbles:true}))}
}
var HTMLElement=Element;function NodeList(){}NodeList.prototype=Array.prototype;function HTMLCollection(){}HTMLCollection.prototype=Array.prototype;var __tagc={};var HTMLDivElement=class extends Element{};__tagc['div']=HTMLDivElement;var HTMLAnchorElement=class extends Element{};__tagc['a']=HTMLAnchorElement;var HTMLImageElement=class extends Element{};__tagc['img']=HTMLImageElement;var HTMLInputElement=class extends Element{};__tagc['input']=HTMLInputElement;var HTMLFormElement=class extends Element{};__tagc['form']=HTMLFormElement;var HTMLScriptElement=class extends Element{};__tagc['script']=HTMLScriptElement;var HTMLIFrameElement=class extends Element{};__tagc['iframe']=HTMLIFrameElement;var HTMLButtonElement=class extends Element{};__tagc['button']=HTMLButtonElement;var HTMLSpanElement=class extends Element{};__tagc['span']=HTMLSpanElement;var HTMLParagraphElement=class extends Element{};__tagc['p']=HTMLParagraphElement;var HTMLUListElement=class extends Element{};__tagc['ul']=HTMLUListElement;var HTMLOListElement=class extends Element{};__tagc['ol']=HTMLOListElement;var HTMLLIElement=class extends Element{};__tagc['li']=HTMLLIElement;var HTMLHeadElement=class extends Element{};__tagc['head']=HTMLHeadElement;var HTMLBodyElement=class extends Element{};__tagc['body']=HTMLBodyElement;var HTMLHtmlElement=class extends Element{};__tagc['html']=HTMLHtmlElement;var HTMLLinkElement=class extends Element{};__tagc['link']=HTMLLinkElement;var HTMLMetaElement=class extends Element{};__tagc['meta']=HTMLMetaElement;var HTMLStyleElement=class extends Element{};__tagc['style']=HTMLStyleElement;var HTMLTemplateElement=class extends Element{};__tagc['template']=HTMLTemplateElement;var HTMLSelectElement=class extends Element{};__tagc['select']=HTMLSelectElement;var HTMLOptionElement=class extends Element{};__tagc['option']=HTMLOptionElement;var HTMLTextAreaElement=class extends Element{};__tagc['textarea']=HTMLTextAreaElement;var HTMLVideoElement=class extends Element{};__tagc['video']=HTMLVideoElement;var HTMLAudioElement=class extends Element{};__tagc['audio']=HTMLAudioElement;var HTMLCanvasElement=class extends Element{};__tagc['canvas']=HTMLCanvasElement;var HTMLTableElement=class extends Element{};__tagc['table']=HTMLTableElement;var HTMLLabelElement=class extends Element{};__tagc['label']=HTMLLabelElement;var HTMLTitleElement=class extends Element{};__tagc['title']=HTMLTitleElement;var HTMLBRElement=class extends Element{};__tagc['br']=HTMLBRElement;var HTMLHRElement=class extends Element{};__tagc['hr']=HTMLHRElement;var HTMLPreElement=class extends Element{};__tagc['pre']=HTMLPreElement;var HTMLSourceElement=class extends Element{};__tagc['source']=HTMLSourceElement;var HTMLPictureElement=class extends Element{};__tagc['picture']=HTMLPictureElement;var HTMLTimeElement=class extends Element{};__tagc['time']=HTMLTimeElement;var HTMLDialogElement=class extends Element{};__tagc['dialog']=HTMLDialogElement;var HTMLDetailsElement=class extends Element{};__tagc['details']=HTMLDetailsElement;var HTMLSlotElement=class extends Element{};__tagc['slot']=HTMLSlotElement;var SVGElement=class extends Element{};['svg','path','g','circle','rect','line','polygon','polyline','use','symbol','defs','clippath','lineargradient','stop','title'].forEach(function(t){if(!__tagc[t]||t=='svg')__tagc[t]=SVGElement});var SVGSVGElement=SVGElement;
class Document extends Node{
 constructor(n){super(n,9);this.readyState='loading';this.cookie='';this.referrer='';this.hidden=false;this.visibilityState='visible';this.compatMode='CSS1Compat'}
 get implementation(){return {hasFeature:function(){return true}}}
 getElementById(i){return __w(__d('i '+i))}
 createElement(t){var e=__w(__d('c '+t));__upgrade(e,String(t).toLowerCase());return e}
 createElementNS(ns,t){return __w(__d('c '+t))}
 createTextNode(s){return __w(__d('x '+s))}
 createComment(s){return __w(__d('x '))}
 createDocumentFragment(){var f=__w(__d('c x-fragment'));f.__frag=true;return f}
 createEvent(){return new Event('')}
 get documentElement(){return this.getElementsByTagName('html')[0]||this.children[0]||null}
 get head(){return this.getElementsByTagName('head')[0]||this.documentElement}
 get body(){return this.getElementsByTagName('body')[0]||this.documentElement}
 get title(){var t=this.getElementsByTagName('title')[0];return t?t.textContent:''}
 set title(v){var t=this.getElementsByTagName('title')[0];if(!t){t=this.createElement('title');var h=this.head;if(h)h.appendChild(t)}t.textContent=v;__host('T'+v)}
 get currentScript(){return __w(__d('S'))}
 get scripts(){return this.getElementsByTagName('script')}
 get images(){return this.getElementsByTagName('img')}
 get links(){return this.getElementsByTagName('a')}
 get forms(){return this.getElementsByTagName('form')}
 get location(){return location}
 get domain(){return location.hostname}
 get URL(){return location.href}
 get defaultView(){return window}
 write(){var s='';for(var i=0;i<arguments.length;i++)s+=arguments[i];__d('w '+s)}
 writeln(){var s='';for(var i=0;i<arguments.length;i++)s+=arguments[i];__d('w '+s+'\n')}
}
var document=__w(1);
var location=(function(){var h=__host('l')||'',m=/^(\w+:)\/\/([^\/?#]*)([^?#]*)(\?[^#]*)?(#.*)?/.exec(h)||[];
 return {href:h,protocol:m[1]||'',host:m[2]||'',hostname:(m[2]||'').replace(/:\d+$/,''),pathname:m[3]||'/',search:m[4]||'',hash:m[5]||'',origin:(m[1]||'')+'//'+(m[2]||''),toString:function(){return this.href},assign:function(){},replace:function(){},reload:function(){}}})();
var performance={timeOrigin:Date.now(),now:function(){return Date.now()-this.timeOrigin},mark:function(){},measure:function(){},clearMarks:function(){},clearMeasures:function(){},getEntries:function(){return[]},getEntriesByType:function(){return[]},getEntriesByName:function(){return[]},timing:{navigationStart:Date.now()},navigation:{type:0}};
var Image=function Image(w,h){var e=document.createElement('img');if(w!==undefined)e.width=w;if(h!==undefined)e.height=h;return e};
function __trs(){var t=__trail(),j,s='',L;for(j=0;j<t.length;j++){L=Math.floor(t[j]/17592186044416);s+=' '+(__texts[L]||'t'+L)+':'+Math.floor(t[j]/16777216)%1048576+':'+t[j]%16777216}return s}
var customElements={_d:{},define:function(n,c){this._d[n]=c;var l=document.querySelectorAll(n);for(var i=0;i<l.length;i++){__upgrade(l[i],n);if(l[i].connectedCallback)try{l[i].connectedCallback()}catch(e){console.log('connectedCallback: '+e+__trs())}}},get:function(n){return this._d[n]},whenDefined:function(n){return new Promise(function(){})},upgrade:function(){}};
// fetch and XMLHttpRequest: the host fetches (GET only so far) when asked with __host('f' + address); the answer comes at once
// ("1", three digits of status, the body; or "0" and why not) and is handed on a moment later, as pages expect. Headers of the answer are not kept.
var Headers=function Headers(h){this._h={};if(h){if(typeof h.forEach=='function'&&!Array.isArray(h)){var t=this;h.forEach(function(v,k){t.set(k,v)})}else if(Array.isArray(h))for(var i=0;i<h.length;i++)this.set(h[i][0],h[i][1]);else for(var k in h)this.set(k,h[k])}};
Headers.prototype={set:function(k,v){this._h[String(k).toLowerCase()]=String(v)},append:function(k,v){k=String(k).toLowerCase();this._h[k]=k in this._h?this._h[k]+', '+v:String(v)},get:function(k){k=String(k).toLowerCase();return k in this._h?this._h[k]:null},has:function(k){return String(k).toLowerCase() in this._h},'delete':function(k){delete this._h[String(k).toLowerCase()]},forEach:function(f,t){for(var k in this._h)f.call(t,this._h[k],k,this)}};
var Response=function Response(body,o){o=o||{};this._b=body==null?'':String(body);this.status=o.status===undefined?200:o.status;this.ok=this.status>=200&&this.status<300;this.statusText=o.statusText||'';this.url=o.url||'';this.headers=new Headers(o.headers);this.type='basic';this.redirected=false;this.bodyUsed=false};
Response.prototype={text:function(){this.bodyUsed=true;return Promise.resolve(this._b)},json:function(){var b=this._b;this.bodyUsed=true;return Promise.resolve().then(function(){return JSON.parse(b)})},clone:function(){return new Response(this._b,this)}};
var Request=function Request(u,o){o=o||{};this.url=String(u&&u.url||u);this.method=(o.method||u&&u.method||'GET').toUpperCase();this.headers=new Headers(o.headers);this.body=o.body};
function __get(u,m,h){if(m!=='GET')return '0only GET requests are made yet';h=h?(''+h).replace(/[\r\n]/g,''):'';return __host('f'+u+(h?'\naccept: '+h:''))}
function fetch(u,o){var r=new Request(u,o);return new Promise(function(ok,no){setTimeout(function(){var a=__get(r.url,r.method,r.headers&&r.headers.get?r.headers.get('accept'):'');if(a.charAt(0)==='1')ok(new Response(a.slice(4),{url:r.url,status:+a.slice(1,4)}));else no(new TypeError('Failed to fetch: '+a.slice(1)))},1)})}
var XMLHttpRequest=function XMLHttpRequest(){this.readyState=0;this.status=0;this.statusText='';this.responseText='';this.response='';this.responseType='';this.responseURL='';this.timeout=0;this.withCredentials=false;this._l={};this.upload={addEventListener:function(){}}};
XMLHttpRequest.UNSENT=0;XMLHttpRequest.OPENED=1;XMLHttpRequest.HEADERS_RECEIVED=2;XMLHttpRequest.LOADING=3;XMLHttpRequest.DONE=4;
XMLHttpRequest.prototype={open:function(m,u){this._m=String(m).toUpperCase();this._u=String(u);this.readyState=1;this._ev('readystatechange')},setRequestHeader:function(k,v){if((''+k).toLowerCase()==='accept')this._acc=v},overrideMimeType:function(){},getResponseHeader:function(){return null},getAllResponseHeaders:function(){return ''},abort:function(){this._off=true},
addEventListener:function(t,f){(this._l[t]=this._l[t]||[]).push(f)},removeEventListener:function(t,f){var l=this._l[t]||[],i=l.indexOf(f);if(i>=0)l.splice(i,1)},
_ev:function(t){var e={type:t,target:this,currentTarget:this,loaded:this.responseText.length,total:this.responseText.length,lengthComputable:true},l=(this._l[t]||[]).slice(),i;if(typeof this['on'+t]=='function')this['on'+t](e);for(i=0;i<l.length;i++)l[i].call(this,e)},
send:function(){var x=this;setTimeout(function(){if(x._off)return;var a=__get(x._u,x._m,x._acc),ok=a.charAt(0)==='1';x.readyState=4;x.responseURL=x._u;if(ok){x.status=+a.slice(1,4);x.statusText=x.status==200?'OK':'';x.responseText=a.slice(4);x.response=x.responseText;if(x.responseType==='json'){try{x.response=JSON.parse(x.responseText)}catch(e){x.response=null}}}
x._ev('readystatechange');x._ev(ok?'load':'error');x._ev('loadend')},1)}};
var navigator={userAgent:'Mozilla/5.0 (Linux; Android 14) Trough/1',language:'en',languages:['en'],platform:'Linux aarch64',onLine:true,cookieEnabled:false,vendor:'',maxTouchPoints:5};
var screen={width:360,height:720,availWidth:360,availHeight:720};
var history={length:1,state:null,pushState:function(){},replaceState:function(){},back:function(){}};
function __store(){var m={};return {getItem:function(k){return k in m?m[k]:null},setItem:function(k,v){m[k]=String(v)},removeItem:function(k){delete m[k]},clear:function(){m={}}}}
var localStorage=__store(),sessionStorage=__store();
function getComputedStyle(){return {getPropertyValue:function(){return ''}}}
function matchMedia(q){return {matches:false,media:q,addListener:function(){},removeListener:function(){},addEventListener:function(){},removeEventListener:function(){}}}
function requestAnimationFrame(f){return setTimeout(f,16)}
function cancelAnimationFrame(t){clearTimeout(t)}
var window=globalThis,self=window,top=window,parent=window,__win=new EventTarget();
var innerWidth=360,innerHeight=720,outerWidth=360,outerHeight=720,devicePixelRatio=1,pageXOffset=0,pageYOffset=0,scrollX=0,scrollY=0;
function scrollTo(){}
function scroll(){}
function addEventListener(t,f){__win.addEventListener(t,f)}
function removeEventListener(t,f){__win.removeEventListener(t,f)}
function dispatchEvent(e){return __win.dispatchEvent(e)}
function __fire(){document.readyState='interactive';document.dispatchEvent(new Event('DOMContentLoaded'));__win.dispatchEvent(new Event('DOMContentLoaded'));document.readyState='complete';var e=new Event('load');__win.dispatchEvent(e);if(typeof window.onload=='function')window.onload(e)}
function __loaded(n,ok){var e=__w(n);if(e)e.dispatchEvent(new Event(ok?'load':'error'))}
// the live screen: elements with a click handler are marked only while the drawn copy is written; a tap there clicks them
function __clicky(o){return o&&((o.__l&&o.__l.click&&o.__l.click.length)||typeof o.onclick=='function')}
function __mark(on){var m=[],k,o;for(k in __nodes){o=__nodes[k];if(o instanceof Element&&__clicky(o))m.push(o)}
 // listeners on the whole page (delegation): its controls are marked too, unless inside a link
 if(__clicky(document)||__clicky(document.body)||__clicky(__win)){var c=document.querySelectorAll('button,[role=button],[tabindex],summary,[data-href]');for(var i=0;i<c.length;i++)if(!c[i].closest('a'))m.push(c[i])}
 for(var j=0;j<m.length;j++){if(on)m[j].setAttribute('data-trough-click',m[j].__n);else m[j].removeAttribute('data-trough-click')}}
function __tap(n){var o=__nodes[n];if(o)o.dispatchEvent(new Event('click',{bubbles:true}))}
// modules: __module(specifier) runs a module once (by its final address) and gives its exports record. The page's importmap is
// read on first use; the host resolves against the importing module's address ('M' base NEWLINE specifier).
var __mods={},__mapd=null,__mbase='';
function __module(s){if(__mapd===null){__mapd={};var l=document.getElementsByTagName('script');for(var i=0;i<l.length;i++)if(l[i].getAttribute('type')==='importmap'){try{var m=JSON.parse(l[i].textContent).imports||{};for(var k in m)__mapd[k]=m[k]}catch(e){}}}
var b=__mbase;if(__mapd[s]!==undefined){s=__mapd[s];b=''}else for(var k in __mapd)if(k.charAt(k.length-1)==='/'&&s.indexOf(k)===0){s=__mapd[k]+s.slice(k.length);b='';break}
var key=b+'\n'+s;if(__mods[key])return __mods[key];var r=s.slice(0,5)==='data:'?'1'+s+'\n'+__dataurl(s):__host('M'+key);if(r.charAt(0)!=='1')throw new TypeError('module '+s+': '+r.slice(1));
var n=r.indexOf('\n'),u=r.slice(1,n);if(__mods[u])return __mods[key]=__mods[u];var ex=__mods[u]=__mods[key]={};
var f;try{f=Function('__exports',r.slice(n+1));__texts[__trail(0)&255]=u.slice(u.lastIndexOf('/')+1)}catch(e){if(e&&e.message)e.message+=' in '+u;throw e}var o=__mbase;__mbase=u;__import.meta.url=u;try{f(ex)}catch(e){if(e&&typeof e.message==='string'&&!e.__named){var t=__trail(),j,s='',L;for(j=0;j<t.length;j++){L=Math.floor(t[j]/17592186044416);s+=' '+(__texts[L]||'t'+L)+':'+Math.floor(t[j]/16777216)%1048576+':'+t[j]%16777216}e.message+=' (running '+u+(s?'; called from'+s:'')+')';try{e.__named=1}catch(_){}}throw e}finally{__mbase=o;__import.meta.url=o||location.href}return ex}
function __dataurl(s){var c=s.indexOf(','),h=s.slice(5,c),b=s.slice(c+1);try{return /;base64$/i.test(h)?atob(b):decodeURIComponent(b)}catch(e){return b.replace(/%([0-9a-fA-F]{2})/g,function(m,x){return String.fromCharCode(parseInt(x,16))})}}
var __import=function(s){try{return Promise.resolve(__module(s))}catch(e){return Promise.reject(e)}};__import.meta={url:location.href};
// URL and URLSearchParams, in the language: resolution by RFC 3986's steps (dot segments removed), getters from the parts
function URLSearchParams(q){this._p=[];if(q&&typeof q==='object'){if(q instanceof URLSearchParams)q=q.toString();else{for(var k in q)this._p.push([k,''+q[k]]);return}}q=''+(q||'');if(q.charAt(0)==='?')q=q.slice(1);var a=q?q.split('&'):[];for(var i=0;i<a.length;i++){if(!a[i])continue;var e=a[i].indexOf('='),d=function(x){try{return decodeURIComponent(x.replace(/\+/g,' '))}catch(_){return x}};this._p.push(e<0?[d(a[i]),'']:[d(a[i].slice(0,e)),d(a[i].slice(e+1))])}}
URLSearchParams.prototype={get:function(k){for(var i=0;i<this._p.length;i++)if(this._p[i][0]===k)return this._p[i][1];return null},getAll:function(k){return this._p.filter(function(p){return p[0]===k}).map(function(p){return p[1]})},has:function(k){return this.get(k)!==null},set:function(k,v){this.delete(k);this._p.push([k,''+v]);this._u&&this._u()},append:function(k,v){this._p.push([k,''+v]);this._u&&this._u()},delete:function(k){this._p=this._p.filter(function(p){return p[0]!==k});this._u&&this._u()},forEach:function(f,t){for(var i=0;i<this._p.length;i++)f.call(t,this._p[i][1],this._p[i][0],this)},keys:function(){return this._p.map(function(p){return p[0]})[Symbol.iterator]()},values:function(){return this._p.map(function(p){return p[1]})[Symbol.iterator]()},entries:function(){return this._p.map(function(p){return [p[0],p[1]]})[Symbol.iterator]()},toString:function(){var e=function(x){return encodeURIComponent(x).replace(/%20/g,'+')};return this._p.map(function(p){return e(p[0])+'='+e(p[1])}).join('&')},get size(){return this._p.length}};
URLSearchParams.prototype[Symbol.iterator]=URLSearchParams.prototype.entries;
function __dots(p){var o=[],s=p.split('/');for(var i=0;i<s.length;i++){var x=s[i];if(x==='..'){if(o.length>1)o.pop();if(i===s.length-1)o.push('')}else if(x==='.'){if(i===s.length-1)o.push('')}else o.push(x)}return o.join('/')}
function URL(u,b){u=''+u;var m=/^([a-zA-Z][\w+.-]*:)(.*)$/.exec(u);if(!m){if(b===undefined)throw new TypeError("Invalid URL: "+u);var B=b instanceof URL?b:new URL(b);
 if(u.slice(0,2)==='//')u=B.protocol+u;else if(u.charAt(0)==='/')u=B.origin+u;else if(u.charAt(0)==='?')u=B.origin+B.pathname+u;else if(u.charAt(0)==='#')u=B.origin+B.pathname+B.search+u;else if(u==='')u=B.origin+B.pathname+B.search;else u=B.origin+B.pathname.replace(/[^\/]*$/,'')+u;m=/^([a-zA-Z][\w+.-]*:)(.*)$/.exec(u)}
 this.protocol=m[1].toLowerCase();var r=m[2],h=/^\/\/([^\/?#]*)(.*)$/.exec(r);this.username='';this.password='';if(h){var a=h[1],at=a.lastIndexOf('@');if(at>=0){var c=a.slice(0,at).split(':');this.username=c[0];this.password=c[1]||'';a=a.slice(at+1)}this.host=a.toLowerCase().replace(/:(80|443)$/,function(x){return(x===':80'&&this.protocol==='http:')||(x===':443'&&this.protocol==='https:')?'':x}.bind(this));r=h[2]}else this.host='';
 var q=/^([^?#]*)(\?[^#]*)?(#.*)?$/.exec(r);this.pathname=h?__dots(q[1]||'/')||'/':q[1];this.search=q[2]&&q[2].length>1?q[2]:'';this.hash=q[3]&&q[3].length>1?q[3]:'';var me=this;this.searchParams=new URLSearchParams(this.search);this.searchParams._u=function(){var t=me.searchParams.toString();me.search=t?'?'+t:''}}
URL.prototype={get hostname(){return this.host.replace(/:\d+$/,'')},get port(){var m=/:(\d+)$/.exec(this.host);return m?m[1]:''},get origin(){return this.host?this.protocol+'//'+this.host:'null'},get href(){return this.protocol+(this.host||this.protocol==='file:'?'//':'')+(this.username?this.username+(this.password?':'+this.password:'')+'@':'')+this.host+this.pathname+this.search+this.hash},toString:function(){return this.href},toJSON:function(){return this.href}};
URL.canParse=function(u,b){try{new URL(u,b);return true}catch(e){return false}};URL.createObjectURL=function(){return 'blob:'+location.origin+'/0'};URL.revokeObjectURL=function(){};
// [by Opus] names pages test for: fragments are elements here; observers never report (nothing is laid out or watched yet)
var DocumentFragment=Element,ShadowRoot=Element,Text=Element,Comment=Element,CharacterData=Element,HTMLTemplateElement=Element,HTMLDialogElement=Element,HTMLButtonElement=Element,HTMLSelectElement=Element,HTMLTextAreaElement=Element,SVGElement=Element;
function __Observer(f){this._f=f}__Observer.prototype={observe:function(){},unobserve:function(){},disconnect:function(){},takeRecords:function(){return[]}};
var IntersectionObserver=function IntersectionObserver(f,o){__Observer.call(this,f);this.root=o&&o.root||null;this.rootMargin=o&&o.rootMargin||'0px';this.thresholds=[0]};IntersectionObserver.prototype=__Observer.prototype;
var MutationObserver=function MutationObserver(f){__Observer.call(this,f)};MutationObserver.prototype=__Observer.prototype;
var ResizeObserver=function ResizeObserver(f){__Observer.call(this,f)};ResizeObserver.prototype=__Observer.prototype;
var PerformanceObserver=function PerformanceObserver(f){__Observer.call(this,f)};PerformanceObserver.prototype=__Observer.prototype;PerformanceObserver.supportedEntryTypes=[];
/* TextEncoder / TextDecoder [by Opus]: UTF-8 only (GitHub's 4u bundle builds on them) */
function TextEncoder(){}TextEncoder.prototype.encoding='utf-8';
TextEncoder.prototype.encode=function(s){s=s===undefined?'':''+s;var o=[],i,c,d;for(i=0;i<s.length;i++){c=s.charCodeAt(i);if(c>=0xd800&&c<0xdc00&&i+1<s.length&&(d=s.charCodeAt(i+1))>=0xdc00&&d<0xe000){c=0x10000+((c-0xd800)<<10)+(d-0xdc00);i++}else if(c>=0xd800&&c<0xe000)c=0xfffd;
if(c<0x80)o.push(c);else if(c<0x800)o.push(0xc0|c>>6,0x80|c&63);else if(c<0x10000)o.push(0xe0|c>>12,0x80|c>>6&63,0x80|c&63);else o.push(0xf0|c>>18,0x80|c>>12&63,0x80|c>>6&63,0x80|c&63)}return new Uint8Array(o)};
TextEncoder.prototype.encodeInto=function(s,a){var b=this.encode(s),n=Math.min(b.length,a.length),i;for(i=0;i<n;i++)a[i]=b[i];return {read:s.length,written:n}};
function TextDecoder(l){this.encoding='utf-8'}
TextDecoder.prototype.decode=function(b){if(b===undefined)return '';if(!(b instanceof Uint8Array))b=new Uint8Array(b.buffer||b,b.byteOffset||0,b.byteLength);var s='',i=0,c,n=b.length;while(i<n){c=b[i++];if(c>=0xf0&&i+2<n){c=(c&7)<<18|(b[i++]&63)<<12|(b[i++]&63)<<6|b[i++]&63}else if(c>=0xe0&&i+1<n){c=(c&15)<<12|(b[i++]&63)<<6|b[i++]&63}else if(c>=0xc0&&i<n){c=(c&31)<<6|b[i++]&63}else if(c>=0x80)c=0xfffd;s+=String.fromCodePoint(c)}return s};
/* AbortController / AbortSignal [by Opus] */
class AbortSignal extends EventTarget{constructor(){super();this.aborted=false;this.reason=undefined;this.onabort=null}
 throwIfAborted(){if(this.aborted)throw this.reason}
 static abort(r){var c=new AbortController();c.abort(r);return c.signal}
 static timeout(ms){var c=new AbortController();setTimeout(function(){c.abort(new Error('TimeoutError'))},ms);return c.signal}
 static any(l){var c=new AbortController();for(var s of l){if(s.aborted){c.abort(s.reason);break}s.addEventListener('abort',function(){c.abort(this.reason)})}return c.signal}}
class AbortController{constructor(){this.signal=new AbortSignal()}
 abort(r){var s=this.signal;if(s.aborted)return;s.aborted=true;s.reason=r===undefined?new Error('AbortError'):r;var e=new Event('abort');if(s.onabort)s.onabort(e);s.dispatchEvent(e)}}
/* custom elements [by Opus]: an element whose tag has a defined class gets that class's prototype and runs its constructor
   on itself (Element's constructor answers with the element being upgraded; super() takes it over as this) */
var __upg=null;function __upgrade(e,n){var c=customElements._d[n];if(!c||e.__up)return;e.__up=1;Object.setPrototypeOf(e,c.prototype);__upg=e;try{new c()}catch(x){console.log('custom element '+n+': '+x)}__upg=null}
/* Blob / File [by Opus]: text only (parts joined); enough for code that builds one and reads its size or text */
class Blob{constructor(p,o){var s='';if(p)for(var x of p)s+=typeof x==='string'?x:x instanceof Blob?x.__s:(x&&x.byteLength!==undefined?new TextDecoder().decode(x):String(x));this.__s=s;this.size=new TextEncoder().encode(s).length;this.type=o&&o.type?String(o.type).toLowerCase():''}
 text(){return Promise.resolve(this.__s)} arrayBuffer(){return Promise.resolve(new TextEncoder().encode(this.__s).buffer)} slice(a,b,t){return new Blob([this.__s.slice(a,b)],{type:t})}}
class File extends Blob{constructor(p,n,o){super(p,o);this.name=String(n);this.lastModified=o&&o.lastModified||Date.now()}}
var crypto={getRandomValues:function(a){for(var i=0;i<a.length;i++)a[i]=Math.floor(Math.random()*Math.pow(2,8*(a.BYTES_PER_ELEMENT||4)));return a},randomUUID:function(){var h='0123456789abcdef',s='',i,c;for(i=0;i<36;i++){if(i==8||i==13||i==18||i==23){s+='-';continue}c=Math.floor(Math.random()*16);if(i==14)c=4;else if(i==19)c=8|c&3;s+=h.charAt(c)}return s}};
(function(){function U(a){try{return new URL(a.getAttribute('href')||'',location.href)}catch(e){return null}}
['protocol','host','hostname','port','pathname','search','hash','origin','username','password'].forEach(function(k){Object.defineProperty(HTMLAnchorElement.prototype,k,{configurable:true,get:function(){var u=U(this);return u?u[k]:''},set:function(v){var u=U(this);if(u&&k!=='origin'){u[k]=v;this.setAttribute('href',u.href)}}})});
Object.defineProperty(HTMLAnchorElement.prototype,'href',{configurable:true,get:function(){var u=U(this);return u?u.href:''},set:function(v){this.setAttribute('href',v)}});
HTMLAnchorElement.prototype.toString=function(){return this.href}})();
var frames=window;
document.createAttribute=function(n){return {name:(''+n).toLowerCase(),value:'',nodeType:2}};
Element.prototype.setAttributeNode=function(a){this.setAttribute(a.name,a.value);return null};
Element.prototype.getAttributeNode=function(n){return this.hasAttribute(n)?{name:n,value:this.getAttribute(n),nodeType:2}:null};
var DocumentType=class extends Node{},DocumentFragment=window.DocumentFragment||class extends Node{},CharacterData=window.CharacterData||class extends Node{},Attr=window.Attr||function Attr(){};
// [by Opus] an iframe's own window: a small, separate one (its document is not loaded or drawn; scripts that write into
// a hidden frame, as analytics loaders do, find what they reach for)
Object.defineProperty(HTMLIFrameElement.prototype,'contentWindow',{configurable:true,get:function(){if(this.__cw)return this.__cw;var w={},d={open:function(){return d},write:function(){},writeln:function(){},close:function(){},createElement:function(t){return document.createElement(t)},getElementById:function(){return null},querySelector:function(){return null},querySelectorAll:function(){return []},addEventListener:function(){},removeEventListener:function(){},readyState:'complete',domain:document.domain,cookie:''};d.body=document.createElement('body');d.head=document.createElement('head');d.documentElement=document.createElement('html');d.defaultView=w;w.document=d;w.window=w;w.self=w;w.parent=window;w.top=window.top||window;w.location={href:'about:blank'};w.addEventListener=function(){};w.removeEventListener=function(){};w.postMessage=function(){};w.setTimeout=setTimeout;w.clearTimeout=clearTimeout;w.Object=Object;w.Array=Array;w.JSON=JSON;w.Promise=Promise;w.navigator=navigator;this.__cw=w;return w}});
Object.defineProperty(HTMLIFrameElement.prototype,'contentDocument',{configurable:true,get:function(){return this.contentWindow.document}});
// [by Opus] el.attributes: named lookups only (the host has no list of names yet, so it is empty to loops)
Object.defineProperty(Element.prototype,'attributes',{configurable:true,get:function(){var e=this;return {length:0,getNamedItem:function(n){return e.hasAttribute(n)?{name:n,value:e.getAttribute(n),nodeValue:e.getAttribute(n)}:null},item:function(){return null},[Symbol.iterator]:function(){return [][Symbol.iterator]()}}}});
var __b64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function btoa(s){s=String(s);var o='',i,a,b,c;for(i=0;i<s.length;i+=3){a=s.charCodeAt(i);b=s.charCodeAt(i+1);c=s.charCodeAt(i+2);if(a>255||b>255||c>255)throw new Error('InvalidCharacterError');o+=__b64.charAt(a>>2)+__b64.charAt(((a&3)<<4)|(b>>4|0))+(i+1<s.length?__b64.charAt(((b&15)<<2)|(c>>6|0)):'=')+(i+2<s.length?__b64.charAt(c&63):'=')}return o}
function atob(s){s=String(s).replace(/[\s=]/g,'');var o='',i,n=0,bits=0,v;for(i=0;i<s.length;i++){v=__b64.indexOf(s.charAt(i));if(v<0)throw new Error('InvalidCharacterError');n=(n<<6)|v;bits+=6;if(bits>=8){bits-=8;o+=String.fromCharCode((n>>bits)&255)}}return o}
window.atob=atob;window.btoa=btoa;
// [by Opus] the event classes pages subclass or test for: each an Event kind keeping the fields its options give
['UIEvent','MouseEvent','KeyboardEvent','FocusEvent','InputEvent','PointerEvent','TouchEvent','WheelEvent','MessageEvent','ErrorEvent','PopStateEvent','HashChangeEvent','StorageEvent','ProgressEvent','AnimationEvent','TransitionEvent','PageTransitionEvent','SubmitEvent','ClipboardEvent','DragEvent'].forEach(function(n){if(window[n])return;var C=function(t,o){var e=new Event(t,o);Object.setPrototypeOf(e,C.prototype);if(o)for(var k in o)if(!(k in e))e[k]=o[k];return e};C.prototype=Object.create(Event.prototype);C.prototype.constructor=C;Object.setPrototypeOf(C,Event);Object.defineProperty(C,'name',{value:n});window[n]=C;try{globalThis[n]=C}catch(e){}});
// [by Opus] DOMParser: the text parsed into a detached element standing for the new document's body
function __DOMParser(){}__DOMParser.prototype.parseFromString=function(s,t){var b=document.createElement('body');try{b.innerHTML=String(s)}catch(e){}var h=document.createElement('html');var d=Object.create(document);var o={nodeType:9,nodeName:'#document',ownerDocument:null,body:b,head:document.createElement('head'),documentElement:h,contentType:t||'text/html',querySelector:function(q){return b.querySelector(q)},querySelectorAll:function(q){return b.querySelectorAll(q)},getElementsByTagName:function(q){return b.getElementsByTagName?b.getElementsByTagName(q):[]},getElementById:function(i){return b.querySelector('#'+i)},createElement:function(t){return document.createElement(t)}};for(var k in o)Object.defineProperty(d,k,{value:o[k],configurable:true,writable:true});return d};
// [by Opus] NodeFilter and tree walkers over ELEMENTS only (text nodes are not walked: SHOW_TEXT finds nothing yet)
var NodeFilter={FILTER_ACCEPT:1,FILTER_REJECT:2,FILTER_SKIP:3,SHOW_ALL:0xFFFFFFFF,SHOW_ELEMENT:1,SHOW_ATTRIBUTE:2,SHOW_TEXT:4,SHOW_CDATA_SECTION:8,SHOW_COMMENT:128,SHOW_DOCUMENT:256,SHOW_DOCUMENT_TYPE:512,SHOW_DOCUMENT_FRAGMENT:1024};window.NodeFilter=NodeFilter;
function __walker(root,what,filter){var all=(what===undefined||(what&1))&&root&&root.querySelectorAll?Array.prototype.slice.call(root.querySelectorAll('*')):[],i=-1,f=filter&&(typeof filter==='function'?filter:filter.acceptNode&&function(n){return filter.acceptNode(n)});
 var ok=function(n){return !f||f(n)===1};var w={root:root,whatToShow:what,filter:filter||null,currentNode:root,
 nextNode:function(){while(++i<all.length)if(ok(all[i]))return w.currentNode=all[i];return null},
 previousNode:function(){while(--i>=0)if(ok(all[i]))return w.currentNode=all[i];i=-1;return null},
 firstChild:function(){return w.nextNode()},parentNode:function(){return null},nextSibling:function(){return w.nextNode()},detach:function(){}};return w}
document.createTreeWalker=__walker;document.createNodeIterator=__walker;
// [by Opus] the character-data node classes, for pages that patch their prototypes (shady DOM)
['Text','Comment','CDATASection','ProcessingInstruction'].forEach(function(n){if(window[n])return;var B=typeof CharacterData==='function'?CharacterData:Node;var C=function(){};C.prototype=Object.create(B.prototype);C.prototype.constructor=C;Object.defineProperty(C,'name',{value:n});window[n]=C;try{globalThis[n]=C}catch(e){}});
// [by Opus] customElements is an instance of CustomElementRegistry (pages patch the class's prototype)
(function(){function CustomElementRegistry(){}var ce=window.customElements||customElements;Object.setPrototypeOf(ce,CustomElementRegistry.prototype);['define','get','whenDefined','upgrade'].forEach(function(k){if(typeof ce[k]==='function')CustomElementRegistry.prototype[k]=ce[k]});window.CustomElementRegistry=CustomElementRegistry;try{globalThis.CustomElementRegistry=CustomElementRegistry}catch(e){}})();
// [by Opus] window's own class: a prototype of its own between window and what it inherited, holding the event methods
if(typeof Window!=='function'){var Window=function Window(){};(function(){var p=Object.create(Object.getPrototypeOf(window));['addEventListener','removeEventListener','dispatchEvent'].forEach(function(k){if(typeof window[k]==='function')p[k]=window[k]});p.constructor=Window;Window.prototype=p;try{Object.setPrototypeOf(window,p)}catch(e){}window.Window=Window})()}
// [by Opus] parsers enabled (unit 72): createHTMLDocument and DOMParser over __DOMParser's detached body
Object.defineProperty(document,"implementation",{configurable:true,get:function(){return {hasFeature:function(){return true},createHTMLDocument:function(t){return new __DOMParser().parseFromString("<title>"+(t||"")+"</title>","text/html")}}}});
window.DOMParser=__DOMParser;
