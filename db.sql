DROP TABLE people CASCADE;
CREATE TABLE people (
    id serial unique primary key,
    name text,
    age numeric CONSTRAINT positive_age CHECK (age >= 0)
);
DROP TABLE nicks CASCADE;
CREATE TABLE nicks(
  id integer REFERENCES people(id),
  nick text NOT NULL
);

insert into
  people
  (name, age)
values
  ('Emily', 33),
  ('Alistair', 33),
  ('Cthu''lhu', 9999),
  ($$Chi'

  - - - !
    ' ' ' ' ' ""nggiz$$, 129);
insert into
   nicks
values
 ((select id from people where name='Emily'), 'Emmy'),
 ((select id from people where name='Emily'), 'Edogg'),
 ((select id from people where name='Alistair'), 'Ally');
SELECT * FROM people left join nicks on people.id = nicks.id;

CREATE TYPE kanjiabcgroup AS ENUM
 ('le', 'ri', 'to', 'bo', 'en', 'fr', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
  'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w',
  'x', 'y', 'z', 'custom');

DROP TABLE characters CASCADE;
CREATE TABLE characters(
  id serial unique primary key,
  svg text NULL, -- to render strokes: OPTIONAL

  -- true if a primitive in Kanji ABC or a custom primitive.
  isprimitive boolean NOT NULL,

  -- true if this char is a kanji that needs decomposition in our app.
  iskanji boolean NOT NULL,
  -- it's ok for isprimitive and iskanji to both be true, e.g., 酉. But it's also
  -- ok for primitives to have decompositions.

  -- types:
  -- radical; jouyou; jinmeiyo; Chinese character (jouyougai); new primitive

  -- some printable representation. If Unicode exists, let it be that. Otherwise
  -- let it be a unique English keyword.
  printable text NOT NULL UNIQUE,

  -- numstrokes integer NOT NULL CHECK (numstrokes > 0),
  kanken real NULL,
  CONSTRAINT kanken_sanity CHECK (kanken >= 0 and kanken <= 10)
);

COPY characters(svg, isprimitive, iskanji, printable, kanken)
  from '/Users/fasih/Dropbox/MobileOrg/kanji-abc/table/char.tsv';
COPY characters(isprimitive, iskanji, printable, kanken)
  from '/Users/fasih/Dropbox/MobileOrg/kanji-abc/table/nonprimchar.tsv';
COPY characters(isprimitive, iskanji, printable, kanken)
  from '/Users/fasih/Dropbox/MobileOrg/kanji-abc/table/jinmeiyou.tsv';

CREATE TABLE IF NOT EXISTS kanjiabc();
DROP TABLE kanjiabc CASCADE;
CREATE TABLE kanjiabc(
  character integer REFERENCES characters(id) ON DELETE CASCADE,
  abcgroup kanjiabcgroup,
  abcnum integer
);

COPY kanjiabc(character, abcgroup, abcnum)
 from '/Users/fasih/Dropbox/MobileOrg/kanji-abc/table/abcs.tsv';

CREATE TABLE IF NOT EXISTS authors();
DROP TABLE authors CASCADE;
CREATE TABLE authors(
  id serial unique primary key
);


CREATE TABLE IF NOT EXISTS decompositions();
DROP TABLE decompositions CASCADE;
CREATE TABLE decompositions(
  id serial unique primary key,
  character integer REFERENCES characters (id) ON DELETE CASCADE,
  creator integer REFERENCES authors (id) ON DELETE RESTRICT,
  unique (id, character)
);

CREATE TABLE IF NOT EXISTS names_for_chars();
DROP TABLE names_for_chars CASCADE;
CREATE TABLE names_for_chars(
  character integer REFERENCES characters (id) ON DELETE CASCADE,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS favorites();
DROP TABLE favorites  CASCADE;
CREATE TABLE favorites(
  character integer REFERENCES decompositions (id) ON DELETE CASCADE,
  author integer REFERENCES authors (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS decomposeds();
DROP TABLE decomposeds CASCADE;
CREATE TABLE decomposeds(
  decomposition serial,
  character serial,
  foreign key (decomposition, character)
   REFERENCES decompositions (id, character)
   ON DELETE CASCADE,

  item integer REFERENCES characters (id) ON DELETE CASCADE,
  CONSTRAINT acyclic CHECK (character != item)
);

-- select primitives -- SELECT printable FROM characters WHERE isprimitive = TRUE;
-- select kanji -- SELECT printable, kanken FROM characters WHERE isprimitive = FALSE ORDER BY kanken DESC NULLS LAST;
