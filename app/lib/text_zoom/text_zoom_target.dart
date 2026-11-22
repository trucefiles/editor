/// What a text zoom applies to; each has a zoom of its own.
enum TextZoomTarget {
  /// The text of files wherever it shows: an open file, card previews,
  /// the calendar tab, the compare view.
  files,

  /// All other text of the app: titles, menus, dialogs, buttons.
  app,
}
