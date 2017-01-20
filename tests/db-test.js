"use strict";
var tape = require("tape");
var db = require("../db.js");

var printAllDepsCallback =
    () => { db.db.all('select * from deps', (e, r) => console.log(e, r)); };

tape("testing", test => {

  db.db.serialize(() => {
    // db.record("一", 'test1', [ 'L3', 'to1' ], printAllDepsCallback);
    db.record("一", 'test1', [ 'L2', 'e3', 'en1' ], printAllDepsCallback);
    db.record("一", 'test3', [ 'L2', 'e3', 'en1' ], printAllDepsCallback);
    db.record("一", 'test2', [ 'L1' ], printAllDepsCallback);
    db.record("西", 'test2', [ 'A1', 'A2' ], printAllDepsCallback);
  });
  test.end();
})

/*

Check it:

// WITH t as (SELECT  group_concat(deps.dependency,",,,") as s FROM deps WHERE deps.target = '一' GROUP BY deps.user) select t.s, count(t.s) as c from t group by t.s order by c desc;

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


CREATE TABLE recipes (
      meal TEXT,
      ingredient TEXT);

INSERT INTO recipes VALUES
  ("tandoori chicken","chicken"), ("tandoori chicken","spices"),
  ("mom's chicken","chicken"), ("mom's chicken","spices"),
  ("spicy chicken","chicken"), ("spicy chicken","spices"),
  ("parmesan chicken","chicken"), ("parmesan chicken","cheese"), ("parmesan chicken","bread"),
  ("breaded chicken","chicken"), ("breaded chicken","cheese"), ("breaded chicken","bread"),
  ("plain chicken","chicken");

  WITH t
       AS (SELECT group_concat(recipes.ingredient, ",,,") AS ingredients
           FROM   recipes
           GROUP  BY recipes.meal)
  SELECT t.ingredients,
         count(t.ingredients) AS cnt
  FROM   t
  GROUP  BY t.ingredients
  ORDER  BY cnt DESC;
 */
