import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/doc_tree.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/doc/origin.dart';
import 'package:truce_markdown/src/edit/commands/command.dart' as commands;
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/print/printer.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

/// A document read from Markdown as Visual edit shows it, after commands.
final class Shown {
  Shown._(this.view, this.origin);

  /// [text] as it shows, checked items in [done] sections if given.
  factory Shown.read(String text, {DoneSections? done}) {
    final loaded = loadMarkdown(text);
    return Shown._(ViewRows(loaded.doc, done: done), loaded.origin);
  }

  final ViewRows view;
  final Origin origin;

  DocTree get doc => view.doc;

  /// What the file says: the document printed.
  String get text => printMarkdown(doc, origin).text;

  /// What each row shows; blocks without text by their kind.
  List<String> get rows => [
    for (final row in view.rows)
      switch (row) {
        TextRow(:final leaf) =>
          '${row.done ? 'done ' : ''}${textOfLeaf(leaf).text}',
        BlockRow(:final leaf) => '[${leaf.runtimeType}]',
      },
  ];

  /// The leaf row [index] shows.
  NodeId leaf(int index) => view.rows[index].leaf.id;

  /// The place [offset] in row [index]'s text.
  Place place(int index, int offset) => Place(leaf(index), offset);

  /// A caret at [offset] in row [index]'s text.
  TextSelection caret(int index, int offset) =>
      TextSelection.caret(place(index, offset));

  /// The text row [index] shows.
  VisibleText textOf(int index) => switch (view.rows[index]) {
    TextRow(:final leaf) => textOfLeaf(leaf),
    final row => throw ArgumentError.value(row, 'index', 'no text'),
  };

  /// This document with its checked items shown as [done] says.
  Shown withDone(DoneSections? done) =>
      Shown._(ViewRows(doc, done: done), origin);

  /// This document after [command], and the selection after it.
  ({Shown document, Selection selection}) run(commands.Command command) {
    final edited = commands.run(view, command);
    return (
      document: Shown._(ViewRows(edited.doc, done: view.done), origin),
      selection: edited.selection,
    );
  }
}

/// The text [leaf] shows.
VisibleText textOfLeaf(DocLeaf leaf) => textOf(leaf);
