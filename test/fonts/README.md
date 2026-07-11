# Todo golden test font

`TodoGoldenSans.ttf` is a glyph-subset of Noto Sans SC used only by Flutter
widget/golden tests. It keeps Chinese text metrics deterministic without adding
a test-only font to production bundles.

Source project: https://github.com/notofonts/noto-cjk/tree/main/Sans

The subset is distributed under the SIL Open Font License 1.1 in `LICENSE`.

`MaterialIcons-Regular.otf` is copied from the Flutter SDK test artifacts so
system icons render deterministically as well. Its license is kept in
`MaterialIcons_LICENSE.txt`.
