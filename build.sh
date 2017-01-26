elm-make Main.elm --output=public/main.js
echo "window['Elm'] = Elm;" >> public/main.js
sed -e "s:main.min.js:main.js:" public/index.html > public/dev.html
yarn run min
