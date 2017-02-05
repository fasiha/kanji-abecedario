"use strict";
var assert = require('assert');
var Promise = require("bluebird");
var tape = require("tape");
var db = require("../db.js");

var printAndReturn = x => {
  console.log("Printing:", x);
  return x;
};

tape("testing", test => {

  Promise
      .delay(200) // SQLite could still be initializating the db
      .then(() => db.firstNoDeps())
      .then(printAndReturn)
      .then(_ => db.record("冫", 'test1', [ '語', '卜', '巾' ]))
      .then(_ => db.firstNoDeps())
      .then(printAndReturn)
      .then(_ => Promise.all([
        db.record("冫", 'test4', [ '卜' ]),
        db.record("冫", 'test3', [ '卜', '巾' ]),
        db.record("冫", 'test2', [ '卜', '巾', '語' ])
      ]))
      .then(_ => db.depsFor('冫'))
      .then(printAndReturn)
      .then(_ => db.record("氵", 'test2', [ '道', '雨' ]))
      .then(_ => db.firstNoDeps())
      .then(printAndReturn)
      .then(_ => db.record("丬", "test4", "目耳口花".split('')))
      .then(_ => db.getPos(1))
      .then(printAndReturn)
      .then(_ => db.getPos(100))
      .then(printAndReturn)
      .then(_ => db.db.allAsync(
                `SELECT target, rowid FROM targets WHERE kanji = 1`))
      .then(gold => {
        assert(JSON.stringify(gold.map(o => o.target).sort()) ===
               JSON.stringify(db.kanjiOnly.sort()));
      })
      .then(_ => db.myDeps("test2"))
      .then(printAndReturn)
      .then(_ => db.myDeps("qweasdzxc"))
      .then(printAndReturn)
      .catch(console.log.bind(console));

  test.end();
});
