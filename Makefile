all: public/main.js

public/main.js: Main.elm
	elm-make Main.elm --output=public/main.js && cp public/main.js public/main.min.js

