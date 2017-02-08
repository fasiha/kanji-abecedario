/* Helper function to convert the output of SQL.js `SELECT * FROM <table>` to
 * CSV. On such a query, SQL.js produces an object like
 *
 * {columns: ['string1','string2', '...', 'stringN'],
 *  values: [[row1_1, row1_2, row1___, row1_N],
 *           [row2_1, row2_2, row2___, row2_N]]}
 *
 * The CSV production is really simple: it just puts commas between elements in
 * arrays. No checks for "quotation marks" or commas. Very simple. Very fragile.
 */
function selection2csv(obj) {
  return [ obj[0].columns.join(',') ]
      .concat(obj[0].values.map(v => v.join(',')))
      .join('\n');
}

/* Big function to wrap
 * - HTTP request to fetch SQLite database
 * - load into SQL.js
 * - two queries to extract the `targets` and `deps` tables
 * - CSV conversion
 * - convert download filename to the downloading user's userhash, if available
 * - open a Save As browser window.
 */
function sql2csv() {
  var xhr = new XMLHttpRequest();
  xhr.open('GET', '/exportdb', true);
  xhr.responseType = 'arraybuffer';

  xhr.onload = function(e) {
    var userhash =
        (xhr.getResponseHeader('Content-Disposition')
             .match(/KanjiBreak-(hash[0-9]+_[a-fA-F0-9]*).sqlite3/) ||
         [])[1];
    var userhashLine = 'me,' + (userhash || '') + '\n\n';

    var filenameVec = xhr.getResponseHeader('Content-Disposition')
                          .match(/KanjiBreak.*sqlite3/);
    var filename = (filenameVec && filenameVec[0] &&
                    filenameVec[0].replace('sqlite3', 'csv')) ||
                   "KanjiBreak.csv";

    var db = new SQL.Database(new Uint8Array(this.response));
    var targets = db.exec("SELECT * FROM targets");
    var deps = db.exec("SELECT * FROM deps");

    var blob = new Blob([ userhashLine + selection2csv(targets) + "\n\n" +
                          selection2csv(deps) ],
                        {type : "text/csv;charset=utf-8;"});

    saveAs(blob, filename);
  };
  xhr.send();
}
