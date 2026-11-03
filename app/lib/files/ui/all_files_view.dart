import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../folders/ui/folder_badge.dart';
import 'file_grid.dart';
import 'file_sections.dart';
import 'listed_file_card.dart';
import 'listed_file_row.dart';

/// Home's All view: every one of [files], newest first or by name, as
/// cards or a list, as [settings] say; by name, the sections follow the
/// order of [folders]. Only what is near the screen is built.
class AllFilesView extends StatelessWidget {
  const AllFilesView(
    this.files, {
    required this.settings,
    required this.folders,
    super.key,
  });

  final List<ListedFile> files;
  final HomeSettings settings;
  final List<Folder> folders;

  @override
  Widget build(BuildContext context) {
    final asCards = settings.view == FileView.cards;
    return CustomScrollView(
      // Pulls down even when the files fit, to refresh.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            asCards ? 12 : 0,
            0,
            asCards ? 12 : 0,
            88,
          ),
          sliver: _files(),
        ),
      ],
    );
  }

  /// Cards built together in by-name order: a few rows in any column
  /// count.
  static const _cardsPerBox = 24;

  Widget _files() => switch ((settings.order, settings.view)) {
    (FileOrder.time, FileView.cards) => fileGrid(
      files.length,
      (index) => ListedFileCard(files[index]),
    ),
    (FileOrder.time, FileView.list) => SliverList.builder(
      itemCount: files.length,
      itemBuilder: (_, index) => ListedFileRow(files[index]),
    ),
    // Each section's cards come in boxes of a few rows, each built only
    // near the screen: a grid per section would build some cards of every
    // section at once.
    (FileOrder.name, FileView.cards) => _rows([
      for (final section in sectionsByName(files, folders: folders)) ...[
        FilesHeading(_placeOf(section)),
        for (final cards in section.files.slices(_cardsPerBox))
          fileGridBox([for (final file in cards) ListedFileCard(file)]),
      ],
    ]),
    (FileOrder.name, FileView.list) => _rows([
      for (final section in sectionsByName(files, folders: folders)) ...[
        // Lined up with the rows' text.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilesHeading(_placeOf(section)),
        ),
        for (final file in section.files) ListedFileRow(file),
      ],
    ]),
  };

  static Widget _rows(List<Widget> rows) => SliverList.builder(
    itemCount: rows.length,
    itemBuilder: (_, index) => rows[index],
  );

  static String _placeOf(FileSection section) =>
      placeName(section.folder, section.subfolder);
}
