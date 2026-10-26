import 'package:truce_markdown/truce_markdown.dart' show EditMode;

/// The mode of a document with no last mode: Visual edit for one with
/// checkboxes and a new one the user is [typing] in right away, else
/// Read.
EditMode firstMode({required bool hasCheckboxes, required bool typing}) =>
    hasCheckboxes || typing ? EditMode.visual : EditMode.read;
