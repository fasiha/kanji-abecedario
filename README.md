# Todo

- [x] Show my vote for a kanji
- [ ] Show list of all my votes
- [ ] Show proper error when submitting bad “free decompositions”
- [x] Implement “Jump to kanji”
- [x] Add router, i.e., `#/13`.
- [x] Show SVG(s) in top-level description instead of internal target name.
  - [ ] Dependencies too!
- [ ] CSS-ify primitives/kanji list
- [ ] Recenter and rescale SVGs (look at [flatten.js](https://gist.github.com/timo22345/9413158) and the following Inkscape CLI invokation: `inkscape --verb=EditSelectAll --verb=SelectionGroup --verb=AlignHorizontalCenter --verb=AlignVerticalCenter --verb=FileSave --verb=FileQuit $(pwd)/FILE.svg`, possibly with needing to pre-set the alignment relative to “Page”)
- [ ] Easy lookup of primitives by existing decompositions
- [ ] Omit real kanji from primitives list.
