import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import 'text_edit_page_controller.dart';
import 'view_page_controller.dart';

/// One view page's model, built by [ViewPages]: the [controller] the
/// screen shows.
final class ViewPage {
  ViewPage._(this.controller, this._leaveOpenEdits, this._closed);

  final ViewPageController controller;
  final void Function() _leaveOpenEdits;
  final void Function() _closed;

  /// Closes the page; a new file is written first, as far as it can be.
  /// Completes with the new file this page added, once written; `null`
  /// if it added none.
  Future<ListedFile?> close() async {
    _closed();
    try {
      await controller.close();
      return controller.written;
    } finally {
      _leaveOpenEdits();
      controller.dispose();
    }
  }
}

/// Builds the model of each view page from the app's parts: the one
/// place that puts one together.
final class ViewPages {
  /// [work] is what a shown file's owner works with. [reachOf] tells a
  /// folder's reach now, [reachSettled] once a running check of it is
  /// over. [delete] deletes a file; [settingsOf] gives a file's settings,
  /// [editSettings] changes them. [openEdits] keeps new files as a
  /// folder goes or the app ends, waiting at most [endWait].
  /// [fileClosed] is told as each page closes.
  ViewPages({
    required this.work,
    required this.reachOf,
    required this.reachSettled,
    required this.delete,
    required this.settingsOf,
    required this.editSettings,
    required this.openEdits,
    required this.endWait,
    required this.fileClosed,
  });

  final ShownWork work;
  final Reach Function(FolderId folder) reachOf;
  final Future<Reach> Function(FolderId folder) reachSettled;
  final DeleteForUndo delete;
  final FileSettings Function(FileKey file) settingsOf;
  final EditSettings editSettings;
  final OpenEdits openEdits;
  final Duration endWait;
  final void Function() fileClosed;

  /// The page of [file], as listed just before.
  ViewPage open(ListedFile file) => _page(shownFileOwner(file, work));

  /// The page of [file], a new one the user just added.
  ViewPage openNew(NewShownFile file) => _page(newShownFileOwner(file, work));

  ViewPage _page(ShownFileOwner owner) {
    final controller = ViewPageController(
      owner,
      read: work.reload,
      reachOf: reachOf,
      reachSettled: reachSettled,
      delete: delete,
      settingsOf: settingsOf,
      editSettings: editSettings,
      endWait: endWait,
    );
    final leave = openEdits.add(
      folder: () => controller.folder,
      secure: (reason) => controller.keep(reason),
      secureForExit: ({required within}) => controller.keep(SecureReason.exit),
    );
    return ViewPage._(controller, leave, fileClosed);
  }
}
