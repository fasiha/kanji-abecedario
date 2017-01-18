"use strict";
var tape = require("tape");
var db = require("../db.js");

var printAllDepsCallback =
    () => { db.db.all('select * from deps', (e, r) => console.log(e, r)); };

tape("testing", test => {

  db.db.serialize(() => {
    db.record("一", 'test1', [ 'L2', 'e3', 'en11' ], printAllDepsCallback);
    // db.record("一", 'test1', [ 'A1' ]);

  })
  // db.record("一", "test1", ['一']);
  test.end();
})
