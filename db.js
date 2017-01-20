"use strict";
var fs = require('fs');
var assert = require('assert');
var sqlite3 = require('sqlite3').verbose();
var crypto = require('crypto');
require('dotenv').config();

var iterations = 1000;
var keylen = 32; // bytes
var digest = "sha256";

function myhash(string, callback) {
  crypto.pbkdf2(string, process.env.SALT, iterations, keylen, digest,
                (err, key) => {
                  if (err) {
                    throw err;
                  }
                  callback(err, Buffer(key, 'binary').toString('base64'));
                });
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

// var db = new sqlite3.Database('foo.db');
var db = new sqlite3.Database(':memory:');
var ready = false;

db.parallelize(() => {
  db.serialize(() => {
    db.run(
        `CREATE TABLE IF NOT EXISTS targets (target TEXT PRIMARY KEY NOT NULL)`);
    var s = sources.sourcesTable.map(o => o.printable)
                .concat(allKanji.split(''))
                .map(s => `("${s}")`)
                .join(',');
    db.run(`INSERT OR IGNORE INTO targets VALUES ${s}`);
  });

  db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS deps (
          target TEXT NOT NULL,
          user TEXT NOT NULL,
          dependency TEXT NOT NULL,
          FOREIGN KEY(target) REFERENCES targets(target),
          FOREIGN KEY(dependency) REFERENCES targets(target))`);
    db.run(`CREATE INDEX IF NOT EXISTS targetUser ON deps (target, user)`);
  });

  ready = true;
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

function record(target, user, depsArray, cb) {
  myhash(user, (_, hash) => {
    db.serialize(() => {
      db.run(`DELETE FROM deps WHERE target = ? AND user = ?`,
             [ target, hash ]);
      var statement = db.prepare(`INSERT INTO deps VALUES (?, "${hash}", ?)`);
      cleanDeps(depsArray).forEach(d => statement.run([ target, d ]));
      if (cb) {
        cb()
      };
    });
  });
}

function depsFor(target, cb) {
  db.all(`WITH t
       AS (SELECT group_concat(deps.dependency, ",,,") AS s
           FROM   deps
           WHERE  deps.target = ?
           GROUP  BY deps.user)
      SELECT t.s,
             count(t.s) AS c
      FROM   t
      GROUP  BY t.s
      ORDER  BY c DESC`,
         [ target ], cb);
}

function firstNoDeps(cb) {
  db.all(
      `SELECT target FROM targets WHERE target NOT IN (SELECT DISTINCT target FROM deps) LIMIT 1`,
      cb);
}

module.exports = {
  db : db,
  record : record,
  depsFor : depsFor,
  firstNoDeps : firstNoDeps,
  cleanup : (cb) => db.close(cb),
};
