function selection2csv(obj) {
  return [ obj[0].columns.join(',') ]
      .concat(obj[0].values.map(v => v.join(',')))
      .join('\n');
}

function sql2csv() {
  var xhr = new XMLHttpRequest();
  xhr.open('GET', '/exportdb', true);
  xhr.responseType = 'arraybuffer';

  xhr.onload = function(e) {
    var uInt8Array = new Uint8Array(this.response);
    var db = new SQL.Database(uInt8Array);
    var targets = db.exec("SELECT * FROM targets");
    var deps = db.exec("SELECT * FROM deps");
    // console.log(selection2csv(targets));
    // console.log(selection2csv(deps));
    var blob = new Blob([ selection2csv(targets) + selection2csv(deps) ],
                        {type : "text/csv;charset=utf-8;"});
    saveAs(blob, "KanjiBreak.csv");
  };
  xhr.send();
}
