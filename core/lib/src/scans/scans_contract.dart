/// The scans owner's contract: what reaches it, what it decides, what it
/// leads to. One per app; it decides when the folders are scanned and
/// which scan is the latest. Generic over the [Folder] and the [Scan]
/// result, so it knows nothing of documents or sync tools.
library;

import '../owners/ask.dart';
import '../owners/effects.dart';

/// What the scans owner handles: inputs anyone may send, and the results
/// of its effects.
sealed class ScansMessage<Folder, Scan> {
  const ScansMessage();
}

// Inputs.

sealed class ScansInput<Folder, Scan> extends ScansMessage<Folder, Scan> {
  const ScansInput();
}

/// Scan now, e.g. after a write, when a document opens, or when the user
/// asks; answered by [Fresh] once a scan that started after this has
/// ended, so it sees every write made before. Scans even while the app
/// is not in use.
final class Refresh<Folder, Scan> extends ScansInput<Folder, Scan>
    implements Asking {
  const Refresh(this.ticket);

  @override
  final Ticket ticket;
}

/// Files in the folders changed; changes that come close together lead
/// to one scan. Ignored while the app is not in use.
final class FilesChanged<Folder, Scan> extends ScansInput<Folder, Scan> {
  const FilesChanged();
}

/// The folders to scan are now [folders]; scanned at once. Nothing is
/// scanned before the first.
final class FoldersChanged<Folder, Scan> extends ScansInput<Folder, Scan> {
  FoldersChanged(List<Folder> folders) : folders = List.unmodifiable(folders);

  final List<Folder> folders;
}

/// Whether the app is in use; while it is not, changes start nothing.
final class Active<Folder, Scan> extends ScansInput<Folder, Scan> {
  const Active({required this.active});

  final bool active;
}

/// How changes are followed changed: one scan, for changes made while
/// nothing was looking.
final class SettingChanged<Folder, Scan> extends ScansInput<Folder, Scan> {
  const SettingChanged();
}

// Results.

sealed class ScansResult<Folder, Scan> extends ScansMessage<Folder, Scan> {
  const ScansResult();
}

/// [ScanAll] found [scan].
final class Scanned<Folder, Scan> extends ScansResult<Folder, Scan> {
  const Scanned(this.id, this.scan);

  final EffectId id;
  final Scan scan;
}

/// A wait for changes to pause, or the longest wait, is over.
final class ChangesWaited<Folder, Scan> extends ScansResult<Folder, Scan> {
  const ChangesWaited(this.id);

  final EffectId id;
}

// Events.

/// The answer to [Refresh]: a scan that started after it has ended.
final class Fresh implements Answering {
  const Fresh(this.ticket);

  @override
  final Ticket ticket;
}

// Effects.

sealed class ScansEffect<Folder, Scan> {
  const ScansEffect();
}

/// Scan [folders]; answered by [Scanned].
final class ScanAll<Folder, Scan> extends ScansEffect<Folder, Scan> {
  const ScanAll(this.id, this.folders);

  final EffectId id;
  final List<Folder> folders;
}

/// Wait [delay] for changes; then [ChangesWaited].
final class WaitForChanges<Folder, Scan> extends ScansEffect<Folder, Scan>
    implements Wait<ChangesWaited<Folder, Scan>> {
  const WaitForChanges(this.id, this.delay);

  @override
  final EffectId id;
  @override
  final Duration delay;

  @override
  ChangesWaited<Folder, Scan> get done => ChangesWaited(id);
}
