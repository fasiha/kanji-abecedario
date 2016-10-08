"use strict";
var fs = require('fs');

var leftpad = (str, desiredLen, padChar) =>
    padChar.repeat(desiredLen - str.length) + str;

function character2svg(char) {
  const fname =
      '../kanji/' + leftpad(char.charCodeAt(0).toString(16), 5, '0') + '.svg';
  return filename2svg(fname, char);
}

function filename2svg(fname, msg) {
  var s;
  try {
    s = fs.readFileSync(fname, 'utf8');
  } catch (e) {
    console.log(`trying to read ${fname} (message: ${msg})`);
    console.log('error', e.message);
    return null;
  }
  return cleansvg(s);
}

function cleansvg(svg) {
  return svg.match(/<svg[\s\S]*/)[0]
      .split('\n')
      .filter(s => s.indexOf('<text ') < 0)
      .join('\n');
}

function keepstrokes(svg, strokes) {
  const alternator = strokes.map(x => '' + x).join('|');
  const re = new RegExp(`id="kvg:[^"]*?-s(${alternator})"`);
  const strokere = /id="kvg:[^"]*?-s/;
  return svg.split('\n')
      .filter(s => !s.match(strokere) || s.match(re))
      .join('\n');
}
console.log(keepstrokes(character2svg("踊"), [ 1, 2 ]));

// from http://stackoverflow.com/a/8273091/500207
function range(start, stop, step) {
  if (typeof stop === 'undefined') {
    stop = start;
    start = 0;
  }
  if (typeof step === 'undefined') step = 1;
  if ((step > 0 && start >= stop) || (step < 0 && start <= stop)) return [];
  var result = [];
  for (var i = start; step > 0 ? i < stop : i > stop; i += step) result.push(i);
  return result;
};

var flatten1 = v => v.reduce((prev, curr) => prev.concat(curr), []);

function rangesStringToArr(s) {
  return flatten1(s.split(',').map(x => {
    const [a, b] = x.split('-');
    return range(+a, +(b || a) + 1);
  }));
}

var heading2base = {};
heading2base.le = '冫氵忄丬亻禾米⻖弓犭扌礻衤糸王木言⻊酉食金馬日月'.split('');
heading2base.ri = '彡刂⻏卩攵頁隹月'.split('');
heading2base.to = '䒑⺌龴⺈宀艹⺮⺲⺍爫'.split('').concat([ 'human', '⻗' ]);
heading2base.bo = 'ハ儿心灬月'.split('');
heading2base.en = '厂广疒⻌廴囗'.split('');
heading2base.fr = '丶,explosion,丨,卜,巾,土,大'.split(',');
heading2base.a = '一ニ人山石耳火川力刀女小少皿子母父㐅凵斤丘羽'.split('');

var columnsHeadings =
    'le,ri,to,bo,en,fr,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z'
        .split(',');
var columns = {};

columns.le = '冫氵忄'.split('').map(character2svg);
columns.le.push(keepstrokes(character2svg('壮'), range(1, 3)));
columns.le = columns.le.concat('亻禾米⻖弓'.split('').map(character2svg));
columns.le.push(keepstrokes(character2svg('猿'), range(1, 3)));
columns.le = columns.le.concat('扌礻衤糸王木言'.split('').map(character2svg));
columns.le.push(keepstrokes(character2svg('踊'), range(1, 7)));
columns.le = columns.le.concat('酉食金馬日月'.split('').map(character2svg));

columns.ri = '彡刂⻏卩攵頁隹月'.split('').map(character2svg);

var range1 = (x, y) => range(x, 1 + y);
columns.to = [
  [ '首', range1(1, 3) ], [ '肖', range1(1, 3) ], [ '甬', range1(1, 2) ],
  [ '急', range1(1, 2) ], [ '安', range1(1, 3) ], [ '草', range1(1, 3) ],
  [ '筒', range1(1, 6) ], [ '夢', range1(4, 8) ], [ '学', range1(1, 5) ],
  [ '妥', range1(1, 4) ], [ '海', range1(4, 5) ], [ '雷', range1(1, 8) ]
].map(([ char, r ]) => keepstrokes(character2svg(char), r));

columns.bo = heading2base.bo.map(character2svg)

columns.en = heading2base.en.map(character2svg);

columns.fr = [ character2svg('丶') ];
// fr = fr.concat(keepstrokes(character2svg('渋'), range1(8,11)));
columns.fr = columns.fr.concat(keepstrokes(character2svg('塁'), range1(6, 9)));
columns.fr = columns.fr.concat('丨,卜,巾,土,大'.split(',').map(character2svg));

// console.log(le.join('\n'))

fs.writeFileSync('index.html',
                 `<!doctype html>
<meta charset="utf-8">
<style>
svg {
    border: 1px solid black;
}
</style>
${columnsHeadings.map(h=>h+'<br>'+(columns[h] || []).join(' ')).join('<br>')}
`)
