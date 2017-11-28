var Dat = require('dat-node');
var mkdirp = require('mkdirp');

var key;
var path = './.data/dat-archive';
mkdirp.sync(path);

Dat(path, {}, function (err, dat) {
  if (err) {
    console.log('DAT ERR', err);
    return;
  }

  // 2. Import the files
  dat.importFiles({ watch: true });

  // 3. Share the files on the network!
  dat.joinNetwork()
  // (And share the link)
  key = dat.key.toString('hex'); // global
  console.log('My Dat link is: dat://', key);

});

module.exports = { key, path };
