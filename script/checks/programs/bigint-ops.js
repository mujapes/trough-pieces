var a=123456789012345678901234567890n,b=-987654321n;
console.log(String(a+b),String(a*b),String(a/b),String(a%b),String(-a),String(2n**100n),String(a&b),String(b>>3n),String(1n<<70n));
console.log(a>b,a<b,b<0,5n==5,String(5n+"x"),typeof (a-b));
try{a+1}catch(e){console.log(e instanceof TypeError, e.message)}
