"use strict";
var tape = require("tape");
var db = require("../db.js");

var printAllDepsCallback =() => { db.db.all('select * from deps', (e, r) => console.log(e, r)); };
tape("testing", test => {

  db.db.serialize(() => {
    db.firstNoDeps((e, r) => console.log("firstNoDeps", e, r));
    db.record("冫", 'test1', [ '卜' ], null);
    db.firstNoDeps((e, r) => console.log("firstNoDeps", e, r));

    db.record("冫", 'test3', [ '卜', '巾' ], null);
    db.record("冫", 'test2', [ '卜' ], null);

    db.depsFor('冫', (e, r) => console.log('depsFor', e, r));

    db.record("氵", 'test2', [ 'A1', 'A2' ], null);

  });
  test.end();
});

/*
# How to get all decompositions for a given target, ranked by popularity:

Check it:

// WITH t as (SELECT  group_concat(deps.dependency,",,,") as s FROM deps WHERE
deps.target = '一' GROUP BY deps.user) select t.s, count(t.s) as c from t group
by t.s order by c desc;

Formatted:

WITH t
     AS (SELECT Group_concat(deps.dependency, ",,,") AS s
         FROM   deps
         WHERE  deps.target = '一'
         GROUP  BY deps.user)
SELECT t.s,
       Count(t.s) AS c
FROM   t
GROUP  BY t.s
ORDER  BY c DESC;

->>

school,,,厂,,,矛|2
冖|1

# How to get the first N=1 target(s) without ANY dependency data, ordered by
rowid:

SELECT target FROM targets WHERE target NOT IN (SELECT DISTINCT target FROM
deps) LIMIT 1;

#


 */
