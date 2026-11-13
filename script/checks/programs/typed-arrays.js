var b=new ArrayBuffer(16),d=new DataView(b);d.setUint32(0,0xdeadbeef);d.setInt16(4,-2,true);d.setFloat64(8,Math.PI);
var u=new Uint8Array(b);console.log(u.length,u[0],u[3],u[4],u[5],d.getUint32(0),d.getInt16(4,true),d.getFloat64(8),d.getUint8(8));
d.setFloat32(0,1.1,true);console.log(d.getFloat32(0,true),Math.fround(1.1),d.getInt8(3));
var i32=new Int32Array([1,-2,3.7]);console.log(i32.length,i32[1],i32[2],i32.byteLength,Int32Array.BYTES_PER_ELEMENT);
var c=new Uint8ClampedArray([300,-5,1.5]);console.log(c[0],c[1],c[2]);var f=new Float32Array(2);f.set([0.1,2]);console.log(f[0],f[1]);
console.log(new Uint16Array(new Uint8Array([1,2,3,4]).buffer)[1],ArrayBuffer.isView(u),u instanceof Uint8Array,Array.from(new Uint8Array(3).fill(9)).join(''));
var dv=new DataView(new ArrayBuffer(8));dv.setFloat64(0,-0.0005);console.log(dv.getFloat64(0),dv.getUint8(0),dv.getFloat32(0));
