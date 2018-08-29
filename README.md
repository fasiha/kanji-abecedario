# KanjiBreak

Just head over to https://kanjibreak.glitch.me/ to see the app and read all about it! See my [blog post](https://fasiha.github.io/post/kanjibreak/) for some background information.

## Run instructions

- Install [Node 8 LTS](https://nodejs.org) (Node 10 fails to build leveldb).
- Clone this repo.
- Make sure `.env` is correct (see `.env.example`)
- Download the KanjiBreak SQLite database from the main app and move it to `./deps.db`.
- Run `npm install`.
- Run `npm run serve`.
