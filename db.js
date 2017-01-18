"use strict";
var fs = require('fs');
var assert = require('assert');
var sqlite3 = require('sqlite3').verbose();
var db = new sqlite3.Database(':memory:');

var ready = false;

var sources = JSON.parse(fs.readFileSync('sources.json', 'utf8'));

db.parallelize(() => {
  db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS targets (target TEXT PRIMARY KEY NOT NULL)`);
    var s = sources.sourcesTable.map(o => `("${o.printable}")`).join(',');
    db.run(`INSERT OR IGNORE INTO targets VALUES ${s}`);
  });

  db.serialize(() => {
    db.run(
        `CREATE TABLE IF NOT EXISTS deps (
          target TEXT NOT NULL,
          user TEXT NOT NULL,
          dependencies TEXT NOT NULL,
          CHECK(dependencies <> ''),
          FOREIGN KEY(target) REFERENCES targets(target))`);
    db.run(
        `CREATE UNIQUE INDEX IF NOT EXISTS targetUser ON deps (target, user)`);
  });

  ready = true;
});

function depsToString(depsArray) {
  return Array.from(new Set(depsArray))
      .filter(s => !s.match(/^\s*$/))
      .sort()
      .join(',');
}

function record(target, user, depsArray, cb) {
  db.run(`INSERT OR REPLACE INTO deps VALUES (${target}, ${user
         }, ${depsToString(depsArray)})`,
         cb);
}

module.exports = {
  db : db,
    record : record,
    cleanup : (cb) => db.close(cb),
};
