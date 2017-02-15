var fs = require('fs');
var _ = require('lodash');
var flatten1 = v => v.reduce((prev, curr) => prev.concat(curr), []);

var bases = JSON.parse(fs.readFileSync('data/svgs.json', 'utf8')).heading2base;
var svgs = JSON.parse(fs.readFileSync('data/svgs.json', 'utf8')).columns;

// This is how many primitives are in each group of KanjiABC originally. Because
// I'm only adding to the ends of each group, I can recover which I've added.
kabcSizes = [
  24, 8,  12, 5,  6,  7,  22, 15, 20, 14, 13, 13, 14, 11, 19, 12,
  12, 24, 20, 25, 10, 16, 17, 11, 26, 18, 6,  22, 12, 11, 17, 22
];

var fmap = require('./fmap');
var news =
    new Set(flatten1(fmap((k, v, len) => v.slice(len), Object.keys(bases),
                          Object.values(bases), kabcSizes)
                         .filter(v => v && v.length)));

var newSvgs = flatten1(
    fmap(
        (k, v, b, len) => _.zip(v.slice(len), b.slice(len)).map(x => [k, ...x]),
        Object.keys(svgs), Object.values(svgs), Object.values(bases), kabcSizes)
        .filter((v) => v.length));

console.log('START NEW TO KANJIABCvvvvvvvvvvv');
console.log(newSvgs
                .map(([ group, svg, name ]) =>
                         `<p><a href="/#target/${name}">${svg} ${name}</a> to ${group.toUpperCase()}</p>`)
                .join('\n')
                .replace(/\n\s*<path/g, '<path'));
console.log('START NEW TO KANJIABC^^^^^^^^^^^^^^^^^^');

// Now, the rest of the work

var a = Object.values(bases).reduce((p, c) => p.concat(c));
a.length;
var s = new Set(a);
s.size;

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
    .map(s => o[s]);

var dict = flatten1(_.map(bases, (vs, k) => vs.map((v, i) => [v, k, i + 1])));
var reps = _.filter(_.groupBy(dict, o => o[0]), (v, k) => v.length > 1);

var base2num = new Map(Object.keys(bases).map((o, i) => [o, i]));
var sortedReps =
    _.sortBy(reps, v => Math.min(...v.map(vv => base2num.get(vv[1]))));

var table = sortedReps.map(
    v => flatten1([ v[0][0], v.map(v => v.slice(1).join('').toUpperCase()) ]));

var repStrings = sortedReps.map(
    v => [v[0][0], v.map(v => v.slice(1).join('').toUpperCase()).join(', ')]
             .join(': '));
console.log(repStrings.map(s => `<li>${s}</li>`).join('\n'));

var engs = _.sortBy(dict.filter(([ s ]) => s.match(/[a-zA-Z]/)),
                    v => base2num.get(v[1]));
var engSvgs = engs.map(v => svgs[v[1]][v[2] - 1]);
var engStrings = engs.map(
    ([ key, a, n ]) => `<a href="/#target/${key}">${key}</a>${news.has(key)
                           ? '⭐️'
                           : ''
                             } = ${a.toUpperCase()}${n}`);

var rows =
    _.zip(engSvgs, engStrings).map(v => v.join(' ')).map(s => `<p>${s}</p>`);
console.log(_.chunk(rows, Math.ceil(rows.length / 4))
                .map(v => v.join('\n'))
                .map(s => `<div class="column">${s}</div>`)
                .join('\n\n')
                .replace(/\n\s*<path/g, '<path'));

console.log('' + rows.length + ' such primitives:');

/*
// See https://en.wikipedia.org/wiki/Web_colors
var colors =
    "Cornsilk,BlanchedAlmond,Gold,DarkKhaki,Wheat,BurlyWood,Tan,RosyBrown,SandyBrown,Goldenrod,DarkGoldenrod,Peru,Chocolate,SaddleBrown,Sienna,Brown,Maroon,Pink,MediumVioletRed,Salmon,IndianRed,Tomato,Crimson,DarkOliveGreen,Olive,YellowGreen,Chartreuse,DarkSeaGreen,MediumSeaGreen,PaleTurquoise,DarkTurquoise,CadetBlue,PowderBlue,DodgerBlue,Navy"
        .split(',');
colors.length
var css = Object.keys(bases).map((s,i) => `svg.col-${s} {
  border: 2px solid ${colors[i]};
}`).join('\n');
console.log(css)
*/
