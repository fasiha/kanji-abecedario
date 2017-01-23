var fs = require('fs');
var bases = JSON.parse(fs.readFileSync('data/svgs.json', 'utf8')).heading2base;

var a = Object.values(bases).reduce((p, c) => p.concat(c));
a.length;
var s = new Set(a);
s.size;
var _ = require('lodash');

console.log(Object.values(_.groupBy(a))
                .filter(v => v.length > 1)
                .map(v => `${v[0]} x ${v.length}`)
                .join('\n'));

var o = _.groupBy(_.zip(Object.keys(bases), Object.values(bases))
                      .map(([ k, vs ]) => vs.map(v => [v, k]))
                      .reduce((p, c) => p.concat(c)),
                  ([ k, v ]) => k)

Object.values(_.groupBy(a))
    .filter(v => v.length > 1)
    .map(v => v[0])
    .map(s => o[s])
