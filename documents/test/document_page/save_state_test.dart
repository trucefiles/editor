import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

void main() {
  test('the save icon shows where the latest edits are', () {
    final theirs = Seen('', const Version(1));
    final cases = <(FileStatus, bool), SaveState>{
      (const InStep(), true): SaveState.editing,
      (const Editing(.inMemory), false): SaveState.editing,
      (const Editing(.onDevice), false): SaveState.onDevice,
      (const Editing(.writing), false): SaveState.onDevice,
      (ChangedElsewhere(theirs), false): SaveState.onDevice,
      (const DeletedElsewhere(), false): SaveState.onDevice,
      (const SaveFailed(), false): SaveState.onDevice,
      (const InStep(), false): SaveState.inFolder,
      (const Unwritten(), false): SaveState.none,
      (const KeptAsConflict(), false): SaveState.none,
    };

    for (final MapEntry(key: (status, unsent), :value) in cases.entries) {
      expect(saveStateOf(status, unsent: unsent), value, reason: '$status');
    }
  });
}
