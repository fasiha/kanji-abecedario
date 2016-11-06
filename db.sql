DROP TABLE people CASCADE;
CREATE TABLE people (
    id serial unique primary key,
    name text,
    age numeric CONSTRAINT positive_age CHECK (age >= 0)
);

insert into
  people
  (name, age)
values
  ('Emmy', 33),
  ('Ally', 33),
  ('Ammy', 33),
  ('Bazi', 330);
SELECT * FROM people;


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

  numstrokes integer NOT NULL CHECK (numstrokes > 0),
  kanken numeric NULL,
  CONSTRAINT kanken_sanity CHECK (kanken >= 0 and kanken <= 10)
);

CREATE TABLE IF NOT EXISTS authors();
DROP TABLE authors CASCADE;
CREATE TABLE authors(
  id serial unique primary key
);


CREATE TABLE IF NOT EXISTS decompositions();
DROP TABLE decompositions CASCADE;
CREATE TABLE decompositions(
  id serial unique primary key,
  target serial REFERENCES characters (id) ON DELETE CASCADE,
  creator serial REFERENCES authors (id) ON DELETE RESTRICT,
  unique (id, target)
);

CREATE TABLE IF NOT EXISTS names_for_chars();
DROP TABLE names_for_chars CASCADE;
CREATE TABLE names_for_chars(
  target serial REFERENCES characters (id) ON DELETE CASCADE,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS favorites();
DROP TABLE favorites  CASCADE;
CREATE TABLE favorites(
  target serial REFERENCES decompositions (id) ON DELETE CASCADE,
  author serial REFERENCES authors (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS decomposeds();
DROP TABLE decomposeds CASCADE;
CREATE TABLE decomposeds(
  target serial,
  targetchar serial,
  foreign key (target, targetchar) REFERENCES decompositions (id, target) ON DELETE CASCADE,

  item serial REFERENCES characters (id) ON DELETE CASCADE,
  CONSTRAINT acyclic CHECK (targetchar != item)
);
