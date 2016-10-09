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

var columnsHeadings =
    'le,ri,to,bo,en,fr,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z'
        .split(',');

var range1 = (x, y) => range(x, 1 + y);
var charRangeToSVG = (char, str) =>
    keepstrokes(character2svg(char), rangesStringToArr(str));

var heading2base = {};
heading2base.le = '冫氵忄丬亻禾米⻖弓犭扌礻衤糸王木言⻊酉食金馬日月'.split('');
heading2base.ri = '彡刂⻏卩攵頁隹月'.split('');
heading2base.to = '䒑⺌龴⺈宀艹⺮⺲⺍爫'.split('').concat([ 'human', '⻗' ]);
heading2base.bo = 'ハ儿心灬月'.split('');
heading2base.en = '厂广疒⻌廴囗'.split('');
heading2base.fr = '丶,explosion,丨,卜,巾,土,大'.split(',');

var columns = {};

columns.le = '冫氵忄'.split('').map(character2svg);
columns.le.push(keepstrokes(character2svg('壮'), range1(1, 3)));
columns.le = columns.le.concat('亻禾米⻖弓'.split('').map(character2svg));
columns.le.push(keepstrokes(character2svg('猿'), range1(1, 3)));
columns.le = columns.le.concat('扌礻衤糸王木言'.split('').map(character2svg));
columns.le.push(keepstrokes(character2svg('踊'), range1(1, 7)));
columns.le = columns.le.concat('酉食金馬日月'.split('').map(character2svg));

columns.ri = '彡刂⻏卩攵頁隹月'.split('').map(character2svg);

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

heading2base.a = '一ニ人山石耳火川力刀女小少皿子母父㐅凵斤丘羽'.split('');
columns.a = heading2base.a.map(character2svg);
columns.a[17] = keepstrokes(character2svg('図'), range1(5, 6));

heading2base.b =
    '口,言,占,加,召,豆,兄,兑,𠂤,㠯,呂,中,虫,middle course,串'.split(',');
columns.b = heading2base.b.map(character2svg);
columns.b[7] = charRangeToSVG('悦', '4-10');
columns.b[8] = charRangeToSVG('帥', '1-6');
columns.b[9] = charRangeToSVG('官', '4-8');
columns.b[13] = charRangeToSVG('貴', '1-5');

heading2base.c =
    '日,旦,亘,旧,白,原,百,門,艮,良,bird,車,目,相,且,自,首,見,貝,則'.split(',');
columns.c = heading2base.c.map(character2svg);
columns.c[10] = charRangeToSVG('鳥', '1-7');

heading2base.d = '田,苗,畐,魚,曽,由,𤰔,曲,曹,甲,申,里,単,果'.split(',');
columns.d = heading2base.d.map(character2svg);
columns.d[6] = charRangeToSVG('恵', '1-6');

heading2base.e = '丁,了,矛,可,奇,牙,示,于,才,寸,付,寺,専'.split(',');
columns.e = heading2base.e.map(character2svg);

function headString(head,str,sep) {
  heading2base[head] = str.split(sep || ',');
  columns[head] = heading2base[head].map(character2svg);
}

headString('f', '十,斗,古,固,早,龺,干,vibrato,平,羊,半,ヰ,韋');
columns.f[7] = charRangeToSVG('謡', '8-17');
columns.f[5] = charRangeToSVG('潮', '4-11');

headString('g', '千,舌,重,禾,釆,壬,廷,手,乗,垂,彳,行,升,隹');

headString('h', '牛,告,先,生,朱,矢,矢,牛,winghorse,乍,竹')
columns.h[8] = charRangeToSVG('勧', '1-11');

headString('i', '士,吉,土,赤,圭,孝,者,工,五,並,亜,西,龶,inferior,青,責,王,主,𦍌');
columns.i[13] = charRangeToSVG('勤','1-10');
columns.i[12] = charRangeToSVG('毒','1-4');
columns.i[18] = charRangeToSVG('差','1-7');

headString('j', '木,釆,喿,林,麻,本,未,末,朮,米,束,東');
columns.j[2] = charRangeToSVG('操','4-16')

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
