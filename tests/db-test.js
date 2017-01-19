"use strict";
var tape = require("tape");
var db = require("../db.js");

var printAllDepsCallback =
    () => { db.db.all('select * from deps', (e, r) => console.log(e, r)); };

tape("testing", test => {

  db.db.serialize(() => {
    db.record("一", 'test1', [ 'L2', 'e3', 'en1' ], printAllDepsCallback);
    db.record("一", 'test1', [ 'L3' ], printAllDepsCallback);
    db.record("一", 'test2', [ 'L1' ], printAllDepsCallback);
  });
  test.end();
})
