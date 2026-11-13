var o={k:function(){return 5},go:function(){var r=[];[1,2].forEach(function(x){r.push(this.k()+x)},this);[1].map(function(x){r.push(this.k())},this);return r.join()}};console.log(o.go());
