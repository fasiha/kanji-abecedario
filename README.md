# Todo

- [ ] Twitter and GitHub links.
- [ ] Once [Dat stabilizes](), publish link.

Done

- [x] Event sourcing: store events with Dat and rebuild the state at each Node startup.
- [x] Show a texty representation of primitive at the top, e.g., for wiktionary.
- [x] If a not-logged-in user adds a primitive and clicks submit, after login, their breakdown isn't preserved. (As implemented now, just ask to login when first selection made if not logged in.)
- [x] Easy lookup of primitives by existing decompositions
- [x] About + Export (static HTML, outside Elm)
- [x] CSS-ify primitives/kanji list and error flash
- [x] Add numbers to hover over primitives
- [x] JWT->session?
- [x] User’s dependency breakdown should autopopulate, so it can be easily added to.
- [x] Complete selected primitives/kanji display
- [x] Better errors
- [x] Show SVGs in dependencies.
- [x] Show list of all my votes
- [x] Show first kanji without my vote.
- [x] Show my vote for a kanji
- [x] Implement “Jump to kanji”
- [x] Add router, i.e., `#/13`.
- [x] Omit real kanji from primitives list.
- [x] Show SVG(s) in top-level description instead of internal target name.
- [x] Full-screen Elm?

Consider?

- [ ] Make `#target/` the default instead of `#pos/`, i.e., link target pointer to the string. Downside: extra-BMP characters or English keywords.
- [ ] Recenter and rescale SVGs (look at [flatten.js](https://gist.github.com/timo22345/9413158) via [SO](http://stackoverflow.com/a/22254240/500207) and the following Inkscape CLI invokation: `inkscape --verb=EditSelectAll --verb=SelectionGroup --verb=AlignHorizontalCenter --verb=AlignVerticalCenter --verb=FileSave --verb=FileQuit $(pwd)/FILE.svg`, possibly with needing to pre-set the alignment relative to “Page”)

Should probably keep a link to this somewhere: https://fasiha.github.io/kanji-abecedario/
