import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/size_texts.dart';
import '../../common/time_texts.dart';
import '../../folders/ui/folder_badge.dart';
import '../../platform/place_opener.dart';

/// What every open file has, as its page knows it: where it is
/// ([folder], [path]), its [type], and [saved], its file as last listed
/// (`null` while a new file has none yet).
typedef FileBasics = ({
  Folder folder,
  RelPath path,
  ShownFileType type,
  ListedFile? saved,
});

/// Shows the File info panel of a file: what every file has
/// ([basics]), then what its type tells ([facts], e.g. a picture's
/// camera), as soon as they are there.
Future<void> showFileInfo(
  BuildContext context,
  FileBasics basics, {
  required FutureOr<List<FileFact>> facts,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => FileInfoPanel(basics, facts: facts),
);

/// The File info panel's content; see [showFileInfo].
class FileInfoPanel extends StatelessWidget {
  const FileInfoPanel(this.basics, {required this.facts, super.key});

  final FileBasics basics;
  final FutureOr<List<FileFact>> facts;

  @override
  Widget build(BuildContext context) {
    final (:folder, :path, :type, :saved) = basics;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text('File info', style: Theme.of(context).textTheme.titleLarge),
            _Row('Name', child: SelectableText(path.name)),
            _Row(
              'Location',
              child: FolderBadge(folder, file: path, cutInMiddle: true),
            ),
            _Row('Type', child: Text(type.name)),
            if (saved != null) ...[
              _Row('Size', child: Text(sizeText(saved.size))),
              _Row('Last changed', child: _Time(saved.modified)),
            ],
            switch (facts) {
              final List<FileFact> facts => _Facts(facts),
              final Future<List<FileFact>> facts => FutureBuilder(
                future: facts,
                builder: (_, read) => switch (read.data) {
                  final facts? => _Facts(facts),
                  null => const SizedBox.shrink(),
                },
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// A type's [facts], one row each.
class _Facts extends StatelessWidget {
  const _Facts(this.facts);

  final List<FileFact> facts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      for (final fact in facts)
        _Row(
          fact.label,
          child: switch (fact) {
            TextFact(:final text) => SelectableText(text),
            TimeFact(:final at) => _Time(at),
            MapPointFact(:final latitude, :final longitude) => _MapPoint(
              latitude,
              longitude,
            ),
          },
        ),
    ],
  );
}

/// One fact: its [label] above its value ([child]).
class _Row extends StatelessWidget {
  const _Row(this.label, {required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      child,
    ],
  );
}

/// [at] with its full date and time, as the app writes them everywhere.
class _Time extends ConsumerWidget {
  const _Time(this.at);

  final DateTime at;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text(ref.watch(timeTextsProvider).full(at));
}

/// A point's coordinates; a tap shows it on a map.
class _MapPoint extends ConsumerWidget {
  const _MapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: () =>
        unawaited(ref.read(placeOpenerProvider).openPoint(latitude, longitude)),
    child: Text(
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
