all: public/main.js public/test.html public/main.min.js

public/main.js: Main.elm
	elm-make Main.elm --output=public/main.js

public/main.min.js: public/main.js
	./node_modules/.bin/uglifyjs public/main.js --compress --mangle  > public/main.min.js &

watch:
	fswatch -0 -o -l .1 *elm | xargs -0 -n 1 -I {} make

public/test.html: public/index.html
	sed -e 's/main\.min\.js/main.js/' public/index.html > public/test.html