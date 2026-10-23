/// What a text zoom applies to; each has a zoom of its own.
enum TextZoomTarget {
  /// Note text wherever notes show: the open note in every mode, card
  /// previews, the compare view.
  notes,

  /// All other text of the app: titles, menus, dialogs, buttons.
  app,
}
