/// What a text zoom applies to; each has a zoom of its own.
enum TextZoomTarget {
  /// Document text wherever documents show: the open document in every mode, card
  /// previews, the compare view.
  documents,

  /// All other text of the app: titles, menus, dialogs, buttons.
  app,
}
