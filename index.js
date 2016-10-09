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

function headString(head, str, sep) {
  heading2base[head] = str.split(sep || ',');
  columns[head] = heading2base[head].map(character2svg);
}

headString('f', '十,斗,古,固,早,龺,干,vibrato,平,羊,半,ヰ,韋');
columns.f[7] = charRangeToSVG('謡', '8-17');
columns.f[5] = charRangeToSVG('潮', '4-11');

headString('g', '千,舌,重,禾,釆,壬,廷,手,乗,垂,彳,行,升,隹');

headString('h', '牛,告,先,生,朱,矢,矢,牛,winghorse,乍,竹')
columns.h[8] = charRangeToSVG('勧', '1-11');

headString('i',
           '士,吉,土,赤,圭,孝,者,工,五,並,亜,西,龶,inferior,青,責,王,主,𦍌');
columns.i[13] = charRangeToSVG('勤', '1-10');
columns.i[12] = charRangeToSVG('毒', '1-4');
columns.i[18] = charRangeToSVG('差', '1-7');

headString('j', '木,釆,喿,林,麻,本,未,末,朮,米,束,東');
columns.j[2] = charRangeToSVG('操', '4-16')

headString('k', '卉,开,廾,廿,革,甘,某,其,井,龷,昔,共');
columns.k[2] = charRangeToSVG('刑', '1-4');
columns.k[9] = charRangeToSVG('黄', '1-4');

headString(
    'l',
    '冖,schoolhouse,erito,売,軍,冂,内,同,周,咼,岡,而,禺,月,肖,用,甫,円,冊,再,冓,舟,几,凡');
columns.l[1] = charRangeToSVG('栄', '1-5');
columns.l[2] = charRangeToSVG('常', '1-8');

headString(
    'm',
    '亠,towa,京,市,亡,方,文,斉,交,亦,立,咅,音,章,意,fasto,辛,tenno,councel,产');
columns.m[18] = charRangeToSVG('商', '1-6');
columns.m[17] = charRangeToSVG('帝', '1-6');
columns.m[15] = charRangeToSVG('新', '1-9');
columns.m[1] = charRangeToSVG('高', '1-5');
columns.m[11] = charRangeToSVG('培', '4-11');
columns.m[19] = charRangeToSVG('産', '1-6');

headString(
    'n',
    '乚,乙,心,必,skyhole,元,酉,尢,匕,化,比,北,旨,兆,七,虍,毛,屯,电,九,卆,丸,㔾,巴,也');
columns.n[4] = charRangeToSVG('空', '1-5');
columns.n[0] = charRangeToSVG('札', '5');
columns.n[18] = charRangeToSVG('竜', '6-10');
columns.n[22] = charRangeToSVG('厄', '3-4');

headString('o', '止,歩,延,卸,正,𤴓,疋,足,走,是');
columns.o[5] = charRangeToSVG('定', '4-8')

headString('p', '水,永,求,farry,𧘇,㐮,衣,mourn,長,辰,氏,氐,民,以,outside,卬')
columns.p[3] = charRangeToSVG('園', '9-12');
columns.p[7] = charRangeToSVG('喪', '9-12');
columns.p[14] = charRangeToSVG('留', '1-5');
columns.p[4] = charRangeToSVG('哀', '6-9');
columns.p[5] = charRangeToSVG('壌', '4-16');
columns.p[11] = charRangeToSVG('低', '3-7');
columns.p[15] = charRangeToSVG('仰', '3-6');

headString('q', '厶,台,能,広,云,至,去,𠫓,育,充,鬼,亥,幺,𢆶,玄,糸,系');
columns.q[7] = charRangeToSVG('棄', '1-4');
columns.q[13] = charRangeToSVG('慈', '4-9');

headString('r', '又,取,叔,隻,祭,殳,圣,奴,反,支,皮');

function fixer(head, key, kanji, rangestr) {
  columns[head][heading2base[head].indexOf(key)] =
      charRangeToSVG(kanji, rangestr);
}

headString(
    's',
    '奐,免,勹,勺,句,旬,dry,勿,万,昜,豕,家,㒸,貇,欠,㳄,夕,舛,名,歹,列,久,夂,复,夋,各');
fixer('s', 'dry', '渇', '4-11');
fixer('s', '㒸', '遂', '1-9');
fixer('s', '貇', '懇', '1-13');
fixer('s', '夋', '唆', '4-10');

headString('t', '癶,𠆢,介,余,金,舎,食,令,今,合,㑒,俞,侖,八,公,㕣,谷,stool');
fixer('t', 'stool', '具', '6-8');
fixer('t', '𠆢', '会', '1-2');
fixer('t', '㑒', '険', '4-11');
fixer('t', '俞', '諭', '8-16');
fixer('t', '㕣', '鉛', '9-13');

headString('u', '尸,辟,尺,戸,扁,倉');

headString(
    'v',
    '右,有,布,real,stable,友,史,更,大,莫,犬,尞,天,关,夫,𦰩,夬,央,夹,龹,𡗗,丰');
fixer('v', 'real', '在', '1-3');
fixer('v', 'stable', '左', '1-2');
fixer('v', '尞', '僚', '3-14');
fixer('v', '𦰩', '嘆', '4-13');
fixer('v', '夹', '狭', '4-9');
fixer('v', '龹', '券', '1-6');
fixer('v', '𡗗', '春', '1-5');
fixer('v', '丰', '邦', '1-4');

headString('w', '弋,spear,代,戈,𢦏,戠,我,義,戊,戌,成,㦮');
fixer('w', 'spear', '武', '1-2,7-8');
fixer('w', '𢦏', '裁', '1-3,10-12');
fixer('w', '㦮', '浅', '4-9');

headString('x', '彐,翟,douse,帚,录,肀,隶,聿,兼,君,争');
fixer('x', 'douse', '侵', '3-9');
fixer('x', '翟', '躍', '8-21');
fixer('x', '录', '緑', '7-14');
fixer('x', '肀', '妻', '2-5');

headString('y', '匚,区,匹,巨,臣,oversee,臤,馬,己,包,弓,弔,弗,丂,考,与,呉');
fixer('y', 'oversee', '監', '1-10');
fixer('y', '臤', '堅', '1-9');
fixer('y', '丂', '号', '4-5')

headString(
    'z',
    '𠃊,rank,非,不,negate,片,zinc,乃,及,𠃌,之,為,入,屰,敢,身,pretty,longsword,敝,鬲,世,trouble');
fixer('z', 'rank', '印', '1-4');
fixer('z', 'negate', '無', '1-8');
fixer('z', 'zinc', '盾', '1-2');
fixer('z', 'pretty', '薦', '4-10');
fixer('z', 'longsword', '帰', '1-2');
fixer('z', 'trouble', '憂', '1-8');
fixer('z', '𠃊', '直', '8');
fixer('z', '𠃌', '司', '1');
fixer('z', '屰', '逆', '1-6');

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
