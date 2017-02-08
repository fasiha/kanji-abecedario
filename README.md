# Todo

- [ ] Twitter and GitHub links.
- [x] If a not-logged-in user adds a primitive and clicks submit, after login, their breakdown isn't preserved. (As implemented now, just ask to login when first selection made if not logged in.)
- [ ] Easy lookup of primitives by existing decompositions
- [ ] Event sourcing: store events with Dat and rebuild the state at each Node startup.

Done

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
