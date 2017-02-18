"use strict";
var _ = require('lodash');
var sets = require('./sets');
var fs = require('fs');

var data = fs.readFileSync('deps.csv', 'utf8')
               .trim()
               .split('\n')
               .slice(1)
               .map(s => s.trim().replace(/"/g, '').split(','));
var items2deps = {};
var deps2items = {};
data.forEach(([ item, _, dep ]) => deps2items[dep] =
                 (deps2items[dep] || new Set([])).add(item));
data.forEach(([ item, _, dep ]) => items2deps[item] =
                 (items2deps[item] || new Set([])).add(dep));

[deps2items['⺈'], items2deps['角']];
[items2deps, deps2items].map(x => Object.values(x).length);

function onewaySearch(deps2items, deps, seen) {
  seen = seen || new Set([]);
  var hits =
      deps.map(source => deps2items[source]).filter(x=>x).reduce((p, c) => sets.union(p, c), new Set([]));
  var newNexts = sets.diff(hits, seen);
  if (newNexts.size === 0) {
    return seen;
  }
  return onewaySearch(deps2items, Array.from(newNexts), sets.union(seen, newNexts));
}
onewaySearch(deps2items, [ '⺈' ]);
onewaySearch(items2deps, [ '角' ]);

/*
And of course, as Derek Sivers could have predicted, this is done more compactly in SQL, see [1], [2].

[1] http://sqlite.org/lang_with.html
[2] https://blog.expensify.com/2015/09/25/the-simplest-sqlite-common-table-expression-tutorial/

sqlite> WITH RECURSIVE alldeps(x) AS (
            VALUES('角')
                UNION
            SELECT deps.dependency
            FROM deps, alldeps
            WHERE deps.target=alldeps.x
        )
        SELECT * FROM alldeps;

sqlite> WITH RECURSIVE alltargets(x) AS (
            VALUES('⺈' )
                UNION
            SELECT deps.target
            FROM deps, alltargets
            WHERE deps.dependency=alltargets.x
        )
        SELECT d.target, group_concat(d.dependency) FROM alltargets inner join deps d on d.target = alltargets.x group by d.target;

Combine the two into a single up/down:

sqlite> WITH RECURSIVE
        alldeps(x) AS (
            VALUES('用')
                UNION
            SELECT deps.dependency
            FROM deps, alldeps
            WHERE deps.target=alldeps.x
        ),
        alltargets(x) AS (
            VALUES('用' )
                UNION
            SELECT deps.target
            FROM deps, alltargets
            WHERE deps.dependency=alltargets.x
        )
        SELECT * FROM alltargets UNION ALL SELECT * FROM alldeps ;

And finally, get the dependencies while you're at it.

sqlite> SELECT d.target,
       group_concat(d.dependency)
FROM   (WITH RECURSIVE
            alldeps(x) AS (
                VALUES ('用')
                  UNION
                SELECT deps.dependency
                FROM   deps,
                       alldeps
                WHERE  deps.target=alldeps.x ),
            alltargets(x) AS (
                VALUES ('用')
                  UNION
                SELECT deps.target
                FROM   deps,
                       alltargets
                WHERE  deps.dependency=alltargets.x )
        SELECT *
        FROM   alltargets
          UNION ALL
        SELECT     *
        FROM       alldeps) AS cte
INNER JOIN deps d
ON         d.target = cte.x
GROUP BY   d.target;

 */
