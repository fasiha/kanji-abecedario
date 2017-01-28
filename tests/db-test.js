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
      .then(_ => db.record("氵", 'test2', [ 'A1', 'A2' ]))
      .then(_ => db.firstNoDeps())
      .then(printAndReturn)
      .then(_ => db.getPos(1))
      .then(printAndReturn)
      .then(_ => db.getPos(100))
      .then(printAndReturn)
      .then(_ => db.db.allAsync(
                `SELECT target, rowid FROM targets WHERE primitive = 0`))
      .then(gold => {
        assert(JSON.stringify(gold.map(o => o.target)) ===
               JSON.stringify(db.kanjiOnly));
      })
      .catch(console.log.bind(console));

  test.end();
});
