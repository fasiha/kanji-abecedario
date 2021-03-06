"use strict";
var Promise = require("bluebird");
var fs = require('fs');
var assert = require('assert');
var sqlite3 = Promise.promisifyAll(require('sqlite3')).verbose();
var path = require('path');
var fs = Promise.promisifyAll(require('fs'));
var mkdirpp = Promise.promisifyAll(require('mkdirp')).mkdirpAsync;
var datdb = require('./datdb');

// DATA
function stringSetDiff(a, b) {
  var aset = new Set(a.split(''));
  return b.split('').filter(s => !aset.has(s)).join('');
}
var kanjiOnly = 'uninit';
// This figures out whether targets are primitives and/or kanji
function makeTargets() {
  var kanken = JSON.parse(fs.readFileSync('data/kanken.json', 'utf8'));
  var allKanji =
      Object.keys(kanken)
          .sort((a, b) => (+b) - (+a)) // descending (10 first, 9, ...)
          .map(k => kanken[k])
          .reduce((prev, curr) => prev + curr);
  // allKanji contains a giant string containing jouyou and jinmeiyou kanji.
  // It might contain some primitives, which we load next:
  var paths = JSON.parse(fs.readFileSync('data/paths.json', 'utf8'));

  // Global mutability
  kanjiOnly = allKanji.split('');

  var kanjiSet = new Set(allKanji.split(''));
  var primSet = new Set(paths.map(o => o.target));
  var seen = new Set([]);
  var all = [];
  for (var target of paths.map(o => o.target).concat(allKanji.split(''))) {
    if (!seen.has(target)) {
      seen.add(target);
      all.push([ target, primSet.has(target) * 1, kanjiSet.has(target) * 1 ]);
    }
  }
  return all;
}

// DB SETUP

var db = new sqlite3.Database('deps.db');

db.runAsync(`PRAGMA foreign_keys = ON`)
    .then(_ => db.runAsync(`CREATE TABLE IF NOT EXISTS targets
                (
                   target    TEXT PRIMARY KEY NOT NULL,
                   primitive BOOLEAN NOT NULL,
                   kanji     BOOLEAN NOT NULL
                )`))
    .then(_ => db.runAsync(`CREATE TABLE IF NOT EXISTS deps (
            target TEXT NOT NULL,
            user TEXT NOT NULL,
            dependency TEXT NOT NULL,
            FOREIGN KEY(target) REFERENCES targets(target),
            FOREIGN KEY(dependency) REFERENCES targets(target))`))
    .then(_ => db.runAsync(
              `CREATE INDEX IF NOT EXISTS targetUser ON deps (target, user)`))
    .then(_ => {
      var allTargets = makeTargets();
      var s = allTargets.map(([ s, i, j ]) => `("${s}",${i},${j})`).join(',');
      return Promise.all([
        db.runAsync(`INSERT OR IGNORE INTO targets VALUES ${s}`),
        // Dump targets to Dat (it will update since timestamp changes)
        fs.writeFileAsync(path.join(datdb.path, 'targets.json'),
                          JSON.stringify(allTargets))
      ]);
    });

// SERVICES

function cleanDeps(depsArray) {
  // Ignore whitespace-only entries and sort.
  return Array.from(new Set(depsArray))
      .filter(s => !s.match(/^\s*$/))
      .map(s => s.trim())
      .sort();
}

var recordStatement = db.prepare(`INSERT INTO deps VALUES (?, ?, ?)`);
var recordDeleteStatement =
    db.prepare(`DELETE FROM deps WHERE target = ? AND user = ?`);
function record(target, user, depsArray) {
  var hash = user;
  var depsToSubmit = cleanDeps(depsArray);

  // Write to file system: will be picked up by Dat: p2p ftw!
  var thispath = path.join(datdb.path, target, hash);
  mkdirpp(thispath)
      .then(made => fs.writeFileAsync(path.join(thispath, 'data.json'),
                                      JSON.stringify(depsToSubmit)))
      .catch(err => console.error("ERROR writing:", thispath, err));

  // Write to database
  return recordDeleteStatement.runAsync([ target, hash ])
      .then(_ => Promise.all(depsToSubmit.map(
                d => recordStatement.runAsync([ target, hash, d ]))));
}

// Note, the following makes no guarantees about sort order of each dependency
// group, unlike other dependency functions here, since this is purely for
// user-export.
var myDepsStatement = db.prepare(`
  SELECT target,
         group_concat(dependency) AS deps
  FROM   deps
  WHERE  deps.USER = ?
  GROUP  BY target`);
function myDeps(hash) { return myDepsStatement.allAsync([ hash ]); }

var depsForStatement = db.prepare(`
  SELECT sortedDeps,
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
                      ORDER  BY cnt DESC`);
function depsFor(target) { return depsForStatement.allAsync([ target ]); }

var userDepsStatement = db.prepare(`
  SELECT group_concat(deps.dependency) AS deps, target
  FROM deps
  WHERE deps.target = ? AND deps.user = ?
  ORDER BY deps.dependency`);
function userDeps(target, hash, cb) {
  return userDepsStatement.allAsync([ target, hash ])
      .then(result => result[0].deps ? result[0] : []);
  // same sort order as depsFor
}

var firstNoDepsStatement = db.prepare(`
  SELECT target, rowid
  FROM targets
  WHERE target NOT IN (SELECT DISTINCT target
                       FROM deps)
  ORDER BY rowid
  LIMIT 1`);
function firstNoDeps() {
  return firstNoDepsStatement.allAsync().then(x => {
    if (x.length > 0) {
      var o = x[0];
      o.deps = [];
      return o;
    }
    return [];
  });
}

var firstNoDepsUserStatement = db.prepare(`
  SELECT target, rowid
  FROM targets
  WHERE target NOT IN (SELECT DISTINCT target
                      FROM deps
                      WHERE deps.user = ?)
  ORDER BY rowid
  LIMIT 1`);
function firstNoDepsUser(hash) {
  return addDepsToTargetRowidPromise(
      firstNoDepsUserStatement.allAsync([ hash ]));
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

var getPosStatement =
    db.prepare('SELECT target, rowid FROM targets WHERE rowid = ?');
function getPos(position) {
  return addDepsToTargetRowidPromise(getPosStatement.allAsync(position));
}

var getTargetStatement =
    db.prepare('SELECT target, rowid FROM targets WHERE target = ?');
function getTarget(target) {
  return addDepsToTargetRowidPromise(getTargetStatement.allAsync(target));
}

var searchTargetStatement = db.prepare(`
  SELECT d.target as target,
         group_concat(d.dependency) as deps
  FROM   (WITH RECURSIVE
              alldeps(x) AS (
                  VALUES (?)
                    UNION
                  SELECT deps.dependency
                  FROM   deps,
                         alldeps
                  WHERE  deps.target=alldeps.x ),
              alltargets(x) AS (
                  VALUES (?)
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
  GROUP BY   d.target`);
// TODO LIMIT needed above?
function searchTarget(target) {
  return searchTargetStatement.allAsync([ target, target ]);
}

module.exports = {
  db,
  record,
  depsFor,
  firstNoDeps,
  firstNoDepsUser,
  userDeps,
  getPos,
  getTarget,
  myDeps,
  searchTarget,
  getKanjiOnly : () => kanjiOnly,
  cleanup : (cb) => db.close(cb),
};

/* Formatted SQL brought to you by http://www.dpriver.com/pp/sqlformat.htm ! */
