"use strict";
var Promise = require("bluebird");
var fs = require('fs');
var assert = require('assert');
var sqlite3 = Promise.promisifyAll(require('sqlite3')).verbose();
var crypto = Promise.promisifyAll(require('crypto'));
require('dotenv').config();

var iterations = 1000;
var keylen = 32; // bytes
var digest = "sha256";

function myhash(string) {
  return crypto
      .pbkdf2Async(string, process.env.SALT, iterations, keylen, digest)
      .then(key => "hash1:" + Buffer(key, 'binary').toString('base64'))
      .catch(console.log.bind(console));
}

// DATA
var stringSetDiff = (a, b) => {
  var aset = new Set(a.split(''));
  return b.split('').filter(s => !aset.has(s)).join('');
};
var kanken = JSON.parse(fs.readFileSync('data/kanken.json', 'utf8'));
var jinmeiyou =
    stringSetDiff(Object.values(kanken).join(''),
                  fs.readFileSync('data/jinmeiyou.txt', 'utf8').trim());
kanken['0'] = jinmeiyou;
var allKanji = Object.keys(kanken)
                   .sort((a, b) => (+b) - (+a)) // descending (10 first, 9, ...)
                   .map(k => kanken[k])
                   .reduce((prev, curr) => prev + curr, '');
// allKanji contains a giant string containing jouyou and jinmeiyou kanji.
// It might contain some primitives, which we load next:
var sources = JSON.parse(fs.readFileSync('data/sources.json', 'utf8'));

var alphanumericToTarget = {};
sources.sourcesTable.forEach(({col, row, printable}) => {
  var key = col + row;
  alphanumericToTarget[key.toUpperCase()] = printable;
  alphanumericToTarget[key.toLowerCase()] = printable;
});

// DB

var db = new sqlite3.Database('deps.db');
// var db = new sqlite3.Database(':memory:');

db.runAsync(`PRAGMA foreign_keys = ON`)
    .then(
        _ => db.runAsync(
            `CREATE TABLE IF NOT EXISTS targets (target TEXT PRIMARY KEY NOT NULL)`))
    .then(_ => db.runAsync(`CREATE TABLE IF NOT EXISTS deps (
            target TEXT NOT NULL,
            user TEXT NOT NULL,
            dependency TEXT NOT NULL,
            FOREIGN KEY(target) REFERENCES targets(target),
            FOREIGN KEY(dependency) REFERENCES targets(target))`))
    .then(_ => db.runAsync(
              `CREATE INDEX IF NOT EXISTS targetUser ON deps (target, user)`))
    .then(_ => {
      var s = sources.sourcesTable.map(o => o.printable)
                  .concat(allKanji.split(''))
                  .map(s => `("${s}")`)
                  .join(',');
      return db.run(`INSERT OR IGNORE INTO targets VALUES ${s}`)
    });

// SERVICES

function cleanDeps(depsArray) {
  // Ignore whitespace-only entries, replace ABC123 codes with our stringy
  // targets, and sort.
  return Array.from(new Set(depsArray))
      .filter(s => !s.match(/^\s*$/))
      .map(s => alphanumericToTarget[s.trim()] || s.trim())
      .sort();
}

function record(target, user, depsArray) {
  return myhash(user).then(hash => {
    var statement = db.prepare(`INSERT INTO deps VALUES (?, ?, ?)`);
    return db
        .runAsync(`DELETE FROM deps WHERE target = ? AND user = ?`,
                  [ target, hash ])
        .then(_ => Promise.all(cleanDeps(depsArray).map(
                  d => statement.runAsync([ target, hash, d ]))));
  });
}

function depsFor(target) {
  return db.allAsync(`SELECT sortedDeps,
                             count(sortedDeps) AS cnt
                      FROM   (SELECT group_concat(d) AS sortedDeps
                              FROM   (SELECT ALL deps.dependency AS d,
                                                 deps.user       AS u
                                      FROM   deps
                                      WHERE  deps.target = ?
                                      GROUP  BY deps.user,
                                                deps.dependency)
                              GROUP  BY u)
                      GROUP  BY sortedDeps
                      ORDER  BY cnt DESC;`,
                     [ target ]);
}

function userDeps(target, user, cb) {
  return myhash(user).then(hash => db.allAsync(`SELECT deps.dependency
                                 FROM deps
                                 WHERE deps.target = ? AND deps.user = ?
                                 ORDER BY deps.dependency`,
                                               [ target, hash ]));
}

function firstNoDeps() {
  return db
      .allAsync(`SELECT target, rowid
                 FROM targets
                 WHERE target NOT IN (SELECT DISTINCT target
                                      FROM deps)
                 LIMIT 1`)
      .then(x => {
        if (x.length > 0) {
          var o = x[0];
          o.deps = [];
          return o;
        }
        return [];
      });
}

function addDepsToTargetRowidPromise(promise) {
  return promise
      .then(x => {
        if (x.length > 0) {
          return Promise.all(
              [ true, x[0].target, x[0].rowid, depsFor(x[0].target) ]);
        }
        return [ false ];
      })
      .then(([ success, target, rowid, deps ]) =>
                success ? {target, rowid, deps} : []);
}

function getPos(position) {
  return addDepsToTargetRowidPromise(db.allAsync(
      'SELECT target, rowid FROM targets WHERE rowid = ?', position));
}

function getTarget(target) {
  return addDepsToTargetRowidPromise(db.allAsync(
      'SELECT target, rowid FROM targets WHERE target = ?', target));
}

module.exports = {
  db,
  record,
  depsFor,
  firstNoDeps,
  userDeps,
  getPos,
  getTarget,
  cleanup : (cb) => db.close(cb),
};
