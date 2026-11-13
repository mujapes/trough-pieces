var s=0,f,i,j,t;
for(i=0;i<7000;i++){t='return ['; for(j=0;j<10;j++)t+='"k'+i+'_'+j+'",'; t+=(i+0.5)+'].length+(function(){return 1})()'; f=new Function(t); s+=f();}
console.log(s);
var o={};o['zz'+1]=5;console.log(new Function('o','return o.zz1+"late"')(o), (function(){return "last"})());
