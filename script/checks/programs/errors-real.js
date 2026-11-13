try{null.x}catch(e){console.log(e instanceof TypeError,e.constructor.name,e.name,Object.keys(e).length,e.constructor===TypeError,String(e).slice(0,9))}
try{undefinedVar}catch(e){console.log(e instanceof ReferenceError,e.constructor.name,e.name,Object.keys(e).length)}
try{throw new RangeError('x')}catch(e){console.log(e.constructor.name,Object.keys(e).length,e.stack===undefined)}
