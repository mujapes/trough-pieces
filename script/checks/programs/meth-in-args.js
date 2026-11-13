function id(o){return o}
function A(e,i){return id({v(e){return typeof i}})}
console.log(A(1,function(){}).v(5));
function A2(e,i){var r=id({v(e){return typeof i}});return r}
console.log(A2(1,function(){}).v(5));
function A3(e,i){var r=[{v(e){return typeof i}}];return r[0]}
console.log(A3(1,function(){}).v(5));
function A4(e,i){var r={v(e){return typeof i}};return r}
console.log(A4(1,function(){}).v(5));
function A5(e,i){return id({v(e){return i}})}
console.log(A5(1,'I').v(5));
