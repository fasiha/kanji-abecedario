var express = require('express');
var path = require('path');
var favicon = require('serve-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var jwt = require('express-jwt');
var cors = require('cors');
var http = require('http');
require('dotenv').config();

var db = require('./db');

var app = express();
var router = express.Router();
var authenticate = jwt({
  secret : process.env.AUTH0_CLIENT_SECRET,
  audience : process.env.AUTH0_CLIENT_ID
});

app.use(cors());

// uncomment after placing your favicon in /public
// app.use(favicon(__dirname + '/public/favicon.ico'));
app.use(logger('dev'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended : false}));
app.use(cookieParser());

app.use(express.static('public'))
app.use('/secured', authenticate);

app.use((err, req, res, next) => {
  if (err.name === 'UnauthorizedError') {
    res.status(401).send('unauthorized');
  }
});

app.get('/ping', (req, res) => {
  res.send("All good. You don't need to be authenticated to call this");
});

app.get('/secured/ping', (req, res) => {
  // console.log("user sub to hash", req.user.sub);
  res.status(200).send(
      "All good. You only get this message if you're authenticated");
});

app.get('/secured/record/:target/:deps', (req, res) => {
  db.record(req.params.target, req.user.sub, req.params.deps.split(','),
            () => res.status(200).send("OK"));
});

app.get('/depsFor/:target', (req, res) => {
  db.depsFor(req.params.target, (err, result) => {
    if (err) {
      console.error("ERROR SQLite, depsFor", err);
      res.status(500).send('database error (depsFor)');
    } else {
      res.json(result);
    }
  });
});

app.get('/firstNoDeps', (req, res) => {
  db.firstNoDeps((err, result) => {
    if (err) {
      console.error("ERROR SQLite, firstNoDeps", err);
      res.status(500).send('database error (firstNoDeps)');
    } else {
      res.json(result);
    }
  });
});

app.get('/secured/userDeps/:target', (req, res) => {
  db.userDeps(req.params.target, req.user.sub, (err, result) => {
    if (err) {
      console.error("ERROR SQLite, userDeps", err);
      res.status(500).send('database error (userDeps)');
    } else {
      res.json(result);
    }
  });
});

app.get('/getPos/:pos', (req, res) => {
  db.getPos(+req.params.pos, (err, result) => {
    if (err) {
      console.error("ERROR SQLite, getPos", err);
      res.status(500).send('database error (getPos)');
    } else {
      res.json(result);
    }
  });
});

// app.get('/userDeps/:target', (req, res) => {
//   db.userDeps(req.params.target, "test1", (err, result) => {
//     if (err) {
//       console.error("ERROR SQLite, userDeps", err);
//       res.status(500).send('database error');
//     } else {
//       res.json(result);
//     }
//   });
// });

var port = process.env.PORT || 3000;

http.createServer(app).listen(
    port, (err) => { console.log('listening in http://localhost:' + port); });

module.exports = app;
