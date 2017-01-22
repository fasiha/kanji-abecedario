"use strict";
var tape = require("tape");
var db = require("../db.js");

var printAllDepsCallback =
    () => { db.db.all('select * from deps', (e, r) => console.log(e, r)); };
tape("testing", test => {

  db.db.serialize(() => {
    db.firstNoDeps((e, r) => console.log("firstNoDeps", e, r));
    db.record("冫", 'test1', [ '語', '卜', '巾' ], null);
    db.firstNoDeps((e, r) => console.log("firstNoDeps", e, r));

    db.record("冫", 'test4', [ '卜' ], null);
    db.record("冫", 'test3', [ '卜', '巾' ], null);
    db.record("冫", 'test2', [ '卜', '巾', '語' ], null);

    db.depsFor('冫', (e, r) => console.log('depsFor', e, r));

    db.record("氵", 'test2', [ 'A1', 'A2' ], null);

    db.getPos(1, (e, r) => console.log("getPos", e, r))
    db.getPos(100, (e, r) => console.log("getPos", e, r))
  });
  test.end();
});
