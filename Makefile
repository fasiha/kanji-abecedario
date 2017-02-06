all: public/main.js public/dev.html

public/main.js: Main.elm
	elm-make Main.elm --output=public/main.js

public/dev.html: public/index.html
	sed -e "s:main.min.js:main.js:" public/index.html > public/dev.html
