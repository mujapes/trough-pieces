class A{#x=1;#m(){return this.#x+1}get v(){return this.#m()}static #s=5;static s(){return A.#s}}
console.log(new A().v, A.s())
