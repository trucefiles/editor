import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../backups/ui/file_backups_screen.dart';
import '../../backups/ui/restore_screen.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../files/file_actions.dart';
import '../../files/file_colors.dart';
import '../../files/file_settings_controller.dart';
import '../../files/show_in_all_files.dart';
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
import '../view_page_controller.dart';
import '../view_pages.dart';
import 'discard_dialog.dart';
import 'edit_place.dart';
import 'file_place_chip.dart';
import 'file_place_spot.dart';
import 'height_reporter.dart';
import 'page_close.dart';
import 'page_delete.dart';
import 'save_indicator.dart';
import 'shown_state_banners.dart';
import 'unreachable_texts.dart';

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
    if (await _controller.mayGo(SecureReason.close, _askToDiscard) && mounted) {
      closeIfOnTop(context);
    }
  }

  Future<AppExitResponse> _onExitRequested() async =>
      await _controller.mayGo(SecureReason.exit, _askToDiscard)
      ? AppExitResponse.exit
      : AppExitResponse.cancel;

  /// Whether the user drops a new file that can be kept nowhere.
  Future<bool> _askToDiscard() async =>
      mounted &&
      await askToDiscard(
        context,
        title: "The file can't be saved",
        message:
            'Neither its folder nor this device could keep it. '
            'Stay to try again or to pick another folder.',
        discard: 'Close and lose it',
      );

  /// Once the file's folder was removed: closes, unless a new file
  /// could not be written before; that one stays, so it can go
  /// elsewhere ([ViewPageController.folderRemoved]).
  void _closeIfNotShown(List<Folder> folders) {
    final folder = _controller.folder;
    if (folder == null || folders.any((shown) => shown.id == folder)) return;
    if (_controller.folderRemoved()) closeAsFolderRemoved(context);
  }

  /// [context] is this screen's.
  Future<void> _delete(BuildContext context) async {
    final outcome = await _controller.deleteFile();
    if (!context.mounted) return;
    tellDeleted(
      context,
      outcome,
      appMessenger: ScaffoldMessenger.of(context),
      actions: ref.read(fileActionsProvider),
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

  /// Asks the user for another place or name of the file, then takes it.
  Future<void> _editPlace() async {
    final at = _controller.place;
    if (at == null) return;
    final title = _controller.title;
    await editPlace(
      context,
      ref,
      at: (folder: at.folder, subfolder: at.path.parent),
      nameField: (name: title, hint: title),
      take: _controller.placeAt,
    );
  }

  void _refresh() => unawaited(_pull.currentState!.refresh());

  /// How tall the banners and place drawn over the view are.
  double _cover = 0;

  void _coverChanged(double height) {
    if (mounted && height != _cover) setState(() => _cover = height);
  }

  /// [page] with the banners and place counted in its top padding too.
  MediaQueryData _coveredBy(MediaQueryData page) => page.copyWith(
    padding: page.padding.copyWith(top: page.padding.top + _cover),
  );

  Widget _menu(BuildContext context, {required FilePlaceSpot placeSpot}) {
    final listed = _controller.listed;
    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        if (placeSpot == FilePlaceSpot.menu)
          PopupMenuItem(
            value: () => unawaited(_editPlace()),
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
          SaveIndicator(
            _controller.saveState,
            onSave: () => unawaited(_controller.saveNow()),
          ),
          if (!acts || !usesTouch(Theme.of(context)))
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          if (acts) _menu(context, placeSpot: placeSpot),
        ],
      ),
      // The type's view fills the whole page ([ViewType.view]); the bar,
      // banners and place go over it, and its top padding says how far.
      extendBodyBehindAppBar: true,
      body: Builder(
        builder: (body) => Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: _coveredBy(MediaQuery.of(body)),
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
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: HeightReporter(
                  onHeight: _coverChanged,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (key != null)
                        if (shown?.conflicts.forFile(key) case final conflict?)
                          ConflictBanner(conflict),
                      if (place != null)
                        UnreachableBanner(
                          place.folder,
                          message: shownUnreachableText(_controller.state),
                        ),
                      ...shownStateBanners(
                        _controller.state,
                        close: () => closeIfOnTop(context),
                        retry: _controller.retry,
                      ),
                      if (place != null && placeSpot == FilePlaceSpot.aboveText)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FilePlaceChip(
                              place.folder,
                              place.path,
                              onPressed: acts
                                  ? () => unawaited(_editPlace())
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
