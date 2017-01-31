# Todo

- [ ] Show list of all my votes
- [ ] Show proper error when submitting bad “free decompositions”
- [ ] Show SVGs in dependencies.
- [ ] CSS-ify primitives/kanji list
- [ ] Easy lookup of primitives by existing decompositions
- [ ] Event sourcing: store events with Dat and rebuild the state at each Node startup.
- [ ] Show first kanji without my vote.

Done

- [x] Show my vote for a kanji
- [x] Implement “Jump to kanji”
- [x] Add router, i.e., `#/13`.
- [x] Omit real kanji from primitives list.
- [x] Show SVG(s) in top-level description instead of internal target name.

Consider?

- [ ] Make `#target/` the default instead of `#pos/`, i.e., link target pointer to the string. Downside: extra-BMP characters or English keywords.
- [ ] Recenter and rescale SVGs (look at [flatten.js](https://gist.github.com/timo22345/9413158) via [SO](http://stackoverflow.com/a/22254240/500207) and the following Inkscape CLI invokation: `inkscape --verb=EditSelectAll --verb=SelectionGroup --verb=AlignHorizontalCenter --verb=AlignVerticalCenter --verb=FileSave --verb=FileQuit $(pwd)/FILE.svg`, possibly with needing to pre-set the alignment relative to “Page”)
