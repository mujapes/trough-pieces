async function* g(){yield 1;await null;yield 2;yield 3}
async function* h(){for await (const z of g()) yield z*10}
(async()=>{let s=[];for await (const x of g()){if(x==3)break;s.push(x)}
for await (let y of [Promise.resolve(5),6]) s.push(y);
for await (const w of h()) s.push(w);
console.log(s.join(','))})();
