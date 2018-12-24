# KanjiBreak

Just head over to https://kanjibreak.glitch.me/ to see the app and read all about it! See my [blog post](https://fasiha.github.io/post/kanjibreak/) for some background information.

## Run instructions

- Install [Node 8 LTS](https://nodejs.org) (Node 10 fails to build leveldb).
- Clone this repo.
- Make sure `.env` is correct (see `.env.example`)
- Download the KanjiBreak SQLite database from the main app and move it to `./deps.db`.
- Run `npm install`.
- Run `npm run serve`.

## Changing kanji or primitives?
First [download KanjiVG](https://github.com/KanjiVG/kanjivg/releases) and unzip it into this directory.

Make changes to `index.js` and run it.

Then start the server per above instructions (basically `npm install` and `npm run serve`, plus other first-time setup things).

Depending on the depth of changes made, you may have to carefully hand-edit an existing `deps.db` SQLite3 database file, since the server won't make changes to any rows in the database if they already exist.