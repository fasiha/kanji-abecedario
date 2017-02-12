var Dat = require('dat-node');
var mkdirp = require('mkdirp');

var key;
var path = './dat-archive';
mkdirp.sync(path);

Dat(path, {}, function(err, dat) {
  console.log('ERR', err);
  // Join the network
  var network = dat.joinNetwork({})
  network.swarm     // hyperdiscovery
  network.connected // number of connected peers

  key = dat.key.toString('hex'); // global
  console.log('Dat key:', key);

  var importer = dat.importFiles({watch : true},
                                 (err, res) => console.log('dat imported'));

  importer.on('file watch event',
              (args) => console.log('Dat fs event: ' + args.path));
});

module.exports = {key, path};
