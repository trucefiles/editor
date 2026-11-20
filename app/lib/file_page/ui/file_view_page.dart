import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../backups/ui/file_backups_screen.dart';
import '../../backups/ui/restore_screen.dart';
import '../../common/snack.dart';
import '../../common/store_error_text.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../files/file_actions.dart';
import '../../files/file_colors.dart';
import '../../files/file_settings_controller.dart';
import '../../files/show_in_all_files.dart';
import '../../files/ui/delete_failure_text.dart';
import '../../files/ui/file_actions_menu.dart';
import '../../files/ui/file_heading.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_badge.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../settings/device_settings_controller.dart';
import '../file_page_wiring.dart';
import '../text_edit_page_controller.dart';
import '../view_page_controller.dart';
import '../view_pages.dart';
import 'edit_shown_place.dart';
import 'file_place_chip.dart';
import 'file_place_spot.dart';

/// The page of a file the app only shows (e.g. an image): its [type]
/// draws it; the page has its name, place and actions. A new file is
/// written as the user leaves or the app is hidden; then leaving tells
/// where it went.
class FileViewPage extends ConsumerStatefulWidget {
  /// The page of [file], as listed just before.
  FileViewPage(ListedFile file, {required this.type, super.key})
    : _open = ((pages) => pages.open(file));

  /// A new file [file] the user just added.
  FileViewPage.fresh(NewShownFile file, {required this.type, super.key})
    : _open = ((pages) => pages.openNew(file));

  final ViewType type;
  final ViewPage Function(ViewPages pages) _open;

  @override
  ConsumerState<FileViewPage> createState() => _FileViewPageState();
}

class _FileViewPageState extends ConsumerState<FileViewPage> {
  late final ViewPage _page;
  late final AppLifecycleListener _lifecycle;
  late final ProviderContainer _container;

  /// The app's messenger, for the hint that outlives this page.
  ScaffoldMessengerState? _appMessenger;
  final _pull = GlobalKey<PullToRefreshState>();

  ViewPageController get _controller => _page.controller;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _page = widget._open(ref.read(viewPagesProvider));
    _controller.addListener(_rebuild);
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_controller.keep(SecureReason.hide)),
      onExitRequested: _onExitRequested,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.removeListener(_rebuild);
    final messenger = _appMessenger;
    unawaited(
      _page.close().then((written) {
        if (written != null) _tellSaved(messenger, written);
      }),
    );
    super.dispose();
  }

  /// Tells where the new file went, with a way to find it there.
  void _tellSaved(ScaffoldMessengerState? messenger, ListedFile file) =>
      messenger?.showHint(
        'Saved to ${placeName(file.folder, file.path.parent)}',
        actionLabel: 'Show',
        onAction: () => showInAllFiles(_container, file),
      );

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Leaves once a new file is kept ([ViewPageController.mayGo]).
  Future<void> _leave() async {
    if (await _controller.mayGo(SecureReason.close, _askToDiscard)) _close();
  }

  Future<AppExitResponse> _onExitRequested() async =>
      await _controller.mayGo(SecureReason.exit, _askToDiscard)
      ? AppExitResponse.exit
      : AppExitResponse.cancel;

  Future<bool> _askToDiscard() async {
    if (!mounted) return false;
    return showConfirmDialog(
      context,
      title: "The image can't be saved",
      message:
          'Neither its folder nor this device could keep it. '
          'Stay to try again or to pick another folder.',
      yes: 'Close and lose it',
      no: 'Stay',
    );
  }

  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.pop(context);
    }
  }

  /// Once the file's folder was removed: closes, unless a new file
  /// could not be written before; that one stays, so it can go
  /// elsewhere.
  void _closeIfNotShown(List<Folder> folders) {
    final folder = _controller.folder;
    if (folder == null || folders.any((shown) => shown.id == folder)) return;
    if (_controller.state is WaitingNew) return;
    ScaffoldMessenger.of(
      context,
    ).showHint('The file closed because its folder was removed from the app.');
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    Navigator.of(context)
      ..popUntil((top) => top == route)
      ..pop();
  }

  /// [context] is this screen's.
  Future<void> _delete(BuildContext context) async {
    final outcome = await _controller.deleteFile();
    if (!context.mounted) return;
    switch (outcome) {
      case NewDropped():
        Navigator.pop(context);
      case DeletedForUndo(:final deleted):
        _offerUndo(ref.read(fileActionsProvider), deleted);
        Navigator.pop(context);
      case DeleteRefused(:final failure):
        showSnack(context, deleteFailureText(failure));
      case AlreadyGone() || FileStopped():
        break;
    }
  }

  void _offerUndo(FileActions actions, UndoableDelete deleted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showHint(
      'File deleted',
      actionLabel: 'Undo',
      onAction: () async {
        if (await actions.undoDelete(deleted) case Err(:final error)) {
          messenger.showHint(error.text);
        }
      },
    );
  }

  Future<void> _pinOrColor(BuildContext context) async {
    await _controller.withFile((file) {
      if (context.mounted) return editPinOrColor(context, ref, file);
    });
  }

  /// Its backups; restoring one replaces the file, which the page then
  /// shows as listed.
  Future<void> _openBackups(BuildContext context, ListedFile file) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => FileBackupsScreen(
            file.key,
            title: _controller.title,
            onOpen: openRestore,
          ),
        ),
      );

  void _refresh() => unawaited(_pull.currentState!.refresh());

  Widget _menu(BuildContext context, {required FilePlaceSpot placeSpot}) {
    final listed = _controller.listed;
    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        if (placeSpot == FilePlaceSpot.menu)
          PopupMenuItem(
            value: () => unawaited(editShownPlace(context, ref, _controller)),
            child: const Text('$placeLabel…'),
          ),
        PopupMenuItem(
          value: () => unawaited(_pinOrColor(context)),
          child: const Text('Pin or color'),
        ),
        if (listed != null)
          PopupMenuItem(
            value: () => unawaited(_openBackups(context, listed)),
            child: const Text('Backups'),
          ),
        if (usesTouch(Theme.of(context)))
          PopupMenuItem(value: _refresh, child: const Text('Refresh')),
        PopupMenuItem(
          value: () => _delete(context),
          child: const Text('Delete file'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(folderContentsProvider, (_, next) {
        if (next.value case final contents?) _controller.observe(contents);
      })
      ..listen(foldersProvider, (_, next) {
        if (next.value case final folders?) _closeIfNotShown(folders);
      });
    if (_controller.folder case final folder?) {
      ref.listen(
        folderReachProvider(folder),
        (_, _) => _controller.reachChanged(),
      );
    }
    return PopScope(
      canPop: _controller.state is! WaitingNew,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Builder(builder: _content),
    );
  }

  Widget _content(BuildContext context) {
    final place = _controller.place;
    final content = _controller.content;
    final shown = ref.watch(folderFilesProvider);
    ref.watch(fileSettingsProvider);
    final mark = _controller.markIn(shown);
    final key = _controller.listed?.key;
    final acts = _controller.actsOnFile;
    final placeSpot = filePlaceSpot(
      aboveText: ref.watch(
        deviceSettingsProvider.select((s) => s.requireValue.placeAboveText),
      ),
      readOnly: !acts,
    );
    final tint = fileTint(mark.color, Theme.of(context).colorScheme);
    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        title: FileHeading(
          title: _controller.title,
          edited: _controller.listed?.modified,
        ),
        actions: [
          if (!acts || !usesTouch(Theme.of(context)))
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          if (acts) _menu(context, placeSpot: placeSpot),
        ],
      ),
      body: Column(
        children: [
          if (key != null)
            if (shown?.conflicts.forFile(key) case final conflict?)
              ConflictBanner(conflict),
          if (place != null)
            UnreachableBanner(
              place.folder,
              message: _controller.state is WaitingNew
                  ? 'The image is kept on this device.'
                  : 'Changes from other devices show once it is back.',
            ),
          ..._stateBanner(),
          if (place != null && placeSpot == FilePlaceSpot.aboveText)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilePlaceChip(
                  place.folder,
                  place.path,
                  onPressed: acts
                      ? () =>
                            unawaited(editShownPlace(context, ref, _controller))
                      : null,
                ),
              ),
            ),
          Expanded(
            child: PullToRefresh(
              key: _pull,
              onRefresh: ref.read(folderContentsProvider.notifier).refresh,
              child: switch (content) {
                final content? => widget.type.view(
                  content,
                  label: _controller.title,
                ),
                null => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }

  /// What the file's state asks the user to know: it is gone, or a new
  /// one could be kept nowhere.
  List<Widget> _stateBanner() => switch (_controller.state) {
    ShownGone() => [
      MaterialBanner(
        leading: const Icon(Icons.delete_outline),
        content: const Text(
          'This file was deleted, moved or renamed elsewhere.',
        ),
        actions: [TextButton(onPressed: _close, child: const Text('Close'))],
      ),
    ],
    WaitingNew(kept: NewKept.nowhere) => [
      MaterialBanner(
        leading: const Icon(Icons.error_outline),
        content: const Text(
          "The image couldn't be saved yet. Try again, or pick another "
          'folder.',
        ),
        actions: [
          TextButton(
            onPressed: _controller.retry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ],
    WaitingNew() || ShownListed() || ShownDropped() => const [],
  };
}
