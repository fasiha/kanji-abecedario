"use strict";
var mkdirp = require('mkdirp');
var fs = require('fs');
var path = require('path');

var db = require('./db');

var datPath = 'foo';

db.db.allAsync('select * from deps')
    .then(alls => alls.reduce(
              (prev, {target, user, dependency}) => {
                var key = JSON.stringify([ target, user ]);
                return prev.set(key,
                                (prev.get(key) || []).concat(dependency).sort())
              },
              new Map([])))
    .then(mymap => mymap.forEach((v, k) => {
      var [target, user] = JSON.parse(k);
      var dest = path.join(datPath, target, user);
      mkdirp.sync(dest);
      fs.writeFileSync(path.join(dest, 'data.json'), JSON.stringify(v));
    }));
