const ClosureCompiler = require('google-closure-compiler-js').webpack;
const path = require('path');

module.exports = {
  entry : [ path.join(__dirname, 'public', 'main.js') ],
  output : {path : path.join(__dirname, 'public'), filename : 'main.min.js'},
  plugins : [ new ClosureCompiler({
    options : {
      compilationLevel : 'ADVANCED',
      createSourceMap : true,
    },
  }) ]
};
