import 'dart:io';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/add_folder/add_folder_flow.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_colors.dart';
import 'package:truce_editor/folders/folder_error.dart';
import 'package:truce_test_support/truce_test_support.dart'
    show FakeFolderMarkers;

import '../../support.dart';

void main() {
  late Directory synced;
  late Directory plain;
  late List<
    ({
      String basePath,
      String toolId,
      Selection selection,
      String name,
      Color color,
    })
  >
  added;

  setUp(() {
    synced = tempFolder();
    plain = tempFolder();
    Directory('${synced.path}/notes/work').createSync(recursive: true);
    Directory('${synced.path}/home').createSync();
    added = [];
  });

  const syncthing = _Tool('syncthing', marker: '.stfolder');
  const other = _Tool('other', marker: '.other');
  const plainFolder = _Tool('plain');

  AddFolderFlow flow([List<DocumentFolder> folders = const []]) {
    final flow = AddFolderFlow(
      AddFolderWork(
        tools: const [other, syncthing, plainFolder],
        markersOf: (path) => FakeFolderMarkers([
          if (path == synced.path) {'.stfolder'} else {},
        ]),
        namesOf: LocalSubfolderNames.new,
        isToolFolder: (_) => false,
        add:
            ({
              required basePath,
              required toolId,
              required selection,
              required name,
              required color,
            }) async {
              added.add((
                basePath: basePath,
                toolId: toolId,
                selection: selection,
                name: name,
                color: color,
              ));
              return const Err(FolderError.overlaps);
            },
      ),
      folders,
    );
    addTearDown(flow.dispose);
    return flow;
  }

  test('a folder a tool recognizes goes on to its parts', () async {
    final adding = flow();

    await adding.pickBase(synced.path);

    expect(adding.step, AddFolderStep.parts);
    expect(adding.tool, syncthing);
  });

  test('the user says which tool syncs a folder none recognizes', () async {
    final adding = flow();

    await adding.pickBase(plain.path);
    expect(adding.step, AddFolderStep.tool);
    adding.chooseTool(plainFolder);

    expect(adding.step, AddFolderStep.parts);
    expect(adding.tool, plainFolder);
  });

  test('a base folder added before keeps its tool, and what its folders '
      'show stays taken', () async {
    final before = folderAt(plain, selection: Selection.of([path('home')]));
    final adding = flow([before]);

    await adding.pickBase(plain.path);

    expect(adding.bases, [before.base]);
    expect(adding.tool, syncthing);
    expect(adding.parts.isTaken(path('home')), isTrue);
    expect(adding.parts.wholeTaken, isTrue);
  });

  test('is named after the one subfolder picked, in a color no folder '
      'has yet', () async {
    final adding = flow([folderAt(plain)]);
    await adding.pickBase(synced.path);
    adding.parts.toggle(path('notes/work'));

    adding.toName();

    expect(adding.step, AddFolderStep.name);
    expect(adding.name, 'work');
    expect(adding.color, nextFolderColor([folderAt(plain).color]));
  });

  test('is named after the base folder when it shows more', () async {
    final adding = flow();
    await adding.pickBase(synced.path);
    adding.parts.chooseWhole(whole: true);

    adding.toName();

    expect(adding.name, synced.path.split('/').last);
  });

  test('adds the folder as chosen, and passes on a refusal', () async {
    final adding = flow();
    await adding.pickBase(synced.path);
    adding.parts
      ..toggle(path('home'))
      ..toggle(path('notes/work'));
    adding
      ..toName()
      ..rename('  Mine ')
      ..recolor(Colors.pink);

    final result = await adding.finish();

    expect(result.error, FolderError.overlaps);
    expect(added.single, (
      basePath: synced.path,
      toolId: 'syncthing',
      selection: Selection.of([path('home'), path('notes/work')]),
      name: 'Mine',
      color: Colors.pink,
    ));
  });

  test('back goes one step back, and ends before the first', () async {
    final adding = flow();
    await adding.pickBase(synced.path);
    adding.parts.chooseWhole(whole: true);
    adding.toName();

    expect(adding.back(), isTrue);
    expect(adding.step, AddFolderStep.parts);
    expect(adding.back(), isTrue);
    expect(adding.step, AddFolderStep.base);
    expect(adding.back(), isFalse);
  });
}

/// A sync tool that recognizes a base folder holding its [marker].
final class _Tool implements SyncTool {
  const _Tool(this.id, {this.marker});

  @override
  final String id;

  final String? marker;

  @override
  Future<SyncStatus> recognize(FolderMarkers markers) async =>
      marker != null && await markers.holds(marker!) == true
      ? SyncStatus.synced
      : SyncStatus.unknown;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
