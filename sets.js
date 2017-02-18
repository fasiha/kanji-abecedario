"use strict";
module.exports = {
  union : (s, t) => new Set([...s, ...t ]),
  int : (s, t) => new Set([...s ].filter(x => t.has(x))),
  diff : (s, t) => new Set([...s ].filter(x => !t.has(x))),
  eq : (s, t) => setdiff(s, t).size === 0 && setdiff(t, s).size === 0
};
