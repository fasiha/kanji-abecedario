"use strict";
module.exports = function fmap(f, ...args) {
  const N = Math.max(...args.map(v => v.length));
  let arr = Array(N);
  for (let i = 0; i < N; i++) {
    arr[i] = f.apply(null, args.map(v => v[i]));
  }
  return arr;
};
