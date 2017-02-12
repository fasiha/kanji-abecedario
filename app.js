var express = require('express');
var path = require('path');
var favicon = require('serve-favicon');
var logger = require('morgan');
var bodyParser = require('body-parser');
var jwt = require('express-jwt');
var session = require('express-session');
var LevelStore = require('level-session-store')(session);
var cors = require('cors');
var http = require('http');
var compression = require('compression');
var assert = require('assert');
require('dotenv').config();
assert(process.env.AUTH0_CLIENT_SECRET && process.env.AUTH0_CLIENT_ID &&
       process.env.SESSION_SECRET && process.env.SALT);

var db = require('./db');

var app = express();
var router = express.Router();
var jwtAuthenticate = jwt({
  secret : process.env.AUTH0_CLIENT_SECRET,
  audience : process.env.AUTH0_CLIENT_ID
});
var sessionAuthenticate = (req, res, next) => {
  if (req.session.user) {
    next();
  } else {
    res.status(401).send('Unauthorized');
  }
};

app.set('x-powered-by', false);
app.use(cors());
app.use(compression()); // Small payloads like JSON responses don't compress...

// uncomment after placing your favicon in /public
app.use(favicon(__dirname + '/public/favicon.ico'));
app.use(logger(
    ':date[iso] :remote-addr :remote-user :method :url HTTP/:http-version :status :res[content-length] - :response-time ms'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended : false}));
app.use(session({
  cookie : {maxAge : 1e3 * 3600 * 24 * 7},
  secret : process.env.SESSION_SECRET,
  resave : false,
  rolling : false,
  saveUninitialized : false,
  store : new LevelStore()
}));

app.use(express.static('public'));
app.use('/data', express.static('data'))
app.use('/api/login', jwtAuthenticate);
app.use('/api/secured', sessionAuthenticate);

app.use((err, req, res, next) => {
  if (err.name === 'UnauthorizedError') {
    res.status(401).send('unauthorized');
  }
});

app.get('/api/login', (req, res) => {
  req.session.user = {sub : req.user.sub};
  res.send("OK");
});

app.get('/api/logout', (req, res) => {
  req.session.destroy(err => {
    if (err) {
      console.error('ERROR destroying session', err);
    }
    res.redirect('/');
  });
});

app.get('/api/ping', (req, res) => {
  res.send("All good. You don't need to be authenticated to call this");
});

app.get('/api/secured/ping', (req, res) => {
  res.status(200).send(
      "All good. You only get this message if you're authenticated");
});

var makeError = (res, errname) => (err => {
  if (err.errno === 19) {
    // somebody tried to record a non-target dependency
    res.status(400).send(err.code);
  } else {
    console.error("ERROR SQLite", errname, err);
    res.status(500).send(`database error (${errname})`);
  }
});

app.post('/api/secured/record/:target', (req, res) => {
  db.record(req.params.target, req.session.user.sub, req.body)
      .then(_ => res.redirect(`/api/getTarget/${req.params.target}`))
      .catch(makeError(res, 'record'));
});

app.get('/api/depsFor/:target', (req, res) => {
  db.depsFor(req.params.target)
      .then(result => res.json(result))
      .catch(makeError(res, 'depsFor'));
});

app.get('/api/firstNoDeps', (req, res) => {
  db.firstNoDeps()
      .then(result => result.length === 0
                          ? res.status(404).send('no rows found')
                          : res.json(result))
      .catch(makeError(res, 'firstNoDeps'));
});

app.get('/api/secured/firstNoDeps', (req, res) => {
  db.firstNoDepsUser(req.session.user.sub)
      .then(result => result.length === 0
                          ? res.status(404).send('no rows found')
                          : res.json(result))
      .catch(makeError(res, 'secured/firstNoDeps'));
});

app.get('/api/exportdb', (req, res) => {
  if (req.session && req.session.user && req.session.user.sub) {
    db.myhash(req.session.user.sub)
        .then(hash => res.status(200).download(
                  __dirname + '/deps.db',
                  `KanjiBreak-${hash.replace(/[:+/=]/g, '_')}.sqlite3`));
    return;
  }
  res.status(200).download(__dirname + '/deps.db', 'KanjiBreak.sqlite3');
});

app.get('/api/secured/userDeps/:target', (req, res) => {
  db.userDeps(req.params.target, req.session.user.sub)
      .then(result => result.length === 0
                          ? res.status(404).send('no rows found')
                          : res.json(result))
      .catch(makeError(res, 'userDeps'));
});

app.get('/api/secured/myDeps', (req, res) => {
  db.myDeps(req.session.user.sub)
      .then(result => res.json(result))
      .catch(makeError(res, 'myDeps'));
});

app.get('/api/getPos/:pos', (req, res) => {
  db.getPos(+req.params.pos)
      .then(result => result.length === 0
                          ? res.status(404).send('no rows found')
                          : res.json(result))
      .catch(makeError(res, 'getPos'));
});

app.get('/api/getTarget/:target', (req, res) => {
  db.getTarget(req.params.target)
      .then(result => result.length === 0
                          ? res.status(404).send('no rows found')
                          : res.json(result))
      .catch(makeError(res, 'getTarget'));
});

app.get('/api/kanjiOnly', (req, res) => { res.json(db.getKanjiOnly()); });

var port = process.env.PORT || 3000;

http.createServer(app).listen(
    port, (err) => { console.log('listening in http://localhost:' + port); });

module.exports = app;
