var express = require('express');
var path = require('path');
var favicon = require('serve-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var dotenv = require('dotenv');
var jwt = require('express-jwt');
var cors = require('cors');
var http = require('http');

var app = express();
var router = express.Router();

dotenv.load();

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
app.get('/', (req, res, next) => res.send(`<h1>Hi there!</h1>`));
app.use('/secured', authenticate);

app.get('/ping', function(req, res) {
  res.send("All good. You don't need to be authenticated to call this");
});

app.get('/secured/ping', function(req, res) {
  res.status(200).send(
      "All good. You only get this message if you're authenticated");
});

var port = process.env.PORT || 3000;

http.createServer(app).listen(port, function(err) {
  console.log('listening in http://localhost:' + port);
});

module.exports = app;
