import 'package:collection/collection.dart';

import '../lines/line.dart';
import '../tree/blocks.dart';
import 'block_freezer.dart';
import 'block_reader.dart';
import 'syntax/block_starts.dart';
import 'syntax/characters.dart';

/// A block and the containers it is in, outermost (the root) first.
typedef PlacedBlock = ({Block block, List<ContainerBlock> path});

/// What a re-read needs of the earlier reading.
abstract interface class EarlierReading {
  List<Line> get lines;
  RootBlock get root;
  Map<String, LinkDefinition> get definitions;

  /// The index of line [id]; only for a line of this reading.
  int indexOf(LineId id);

  /// The blocks that start at line [id], outermost first: a leaf at its
  /// first line, an item at its marker line, a container at its first
  /// child's. A block read from the same paragraph as the one right
  /// before it (text after link definitions, a table after text) starts
  /// at none.
  List<PlacedBlock> startsAt(LineId id);

  /// Every block whose first line is [id], outermost first, those read
  /// from the same paragraph as the block before them too.
  List<Block> firstAt(LineId id);
}

/// A reading of lines: the [root] read and the link [definitions] by
/// normalized label; [nextBlockId] is free for the next new block.
typedef NoteReading = ({
  RootBlock root,
  Map<String, LinkDefinition> definitions,
  int nextBlockId,
});

/// Ids that blocks read anew take, by kind and first line, outermost
/// first where blocks of one kind start at one line.
typedef PlannedIds = Map<(BlockKind, LineId), List<BlockId>>;

/// Reads all of [lines]; new blocks get ids from [nextBlockId] on.
NoteReading readNote(List<Line> lines, {int nextBlockId = 0}) {
  final ids = _Ids(nextBlockId);
  final indexes = {for (final (index, line) in lines.indexed) line.id: index};
  final (:root, stoppedAt: _) = readOpenBlocks(
    lines,
    lineIndex: (id) => indexes[id]!,
  );
  final definitions = _byLabel(definitionsRead(root));
  return (
    root: freezeBlocks(
      root,
      lines,
      newId: (_, _) => ids.fresh(),
      definitions: definitions,
      lineIndex: (id) => indexes[id]!,
    ),
    definitions: definitions,
    nextBlockId: ids.next,
  );
}

/// Reads [lines], which are [old]'s lines with those from [start] to
/// [end] replaced by [count] lines, by reading only from the block before
/// the change until the reading lines up with the earlier one again; the
/// rest is kept. Blocks read anew take their [planned] ids, else the ids
/// of the earlier blocks they replace, by kind and first line; others get
/// ids from [nextBlockId] on. Reads as [readNote] would.
NoteReading rereadNote(
  EarlierReading old,
  List<Line> lines, {
  required int start,
  required int end,
  required int count,
  required int nextBlockId,
  PlannedIds planned = const {},
}) {
  final shift = start + count - end;
  if (_frontMatterMayChange(old, lines, start, start + count)) {
    return _readAnew(old, lines, nextBlockId, planned);
  }
  final resume = _resumePoint(old, start);
  int lineIndex(LineId id) {
    final index = old.indexOf(id);
    return index < start ? index : index + shift;
  }

  final (:root, :stoppedAt) = readOpenBlocks(
    lines,
    resume: resume.point,
    stop: _Stops(old, shift, from: start + count),
    lineIndex: lineIndex,
  );
  final stopOld = stoppedAt == null ? old.lines.length : stoppedAt - shift;
  final ids = _Ids(nextBlockId);
  final plan = _Plan(planned);
  final inherited = plan.ids;
  BlockId newId(BlockKind kind, LineId firstLine) {
    if (plan.take(kind, firstLine) case final id?) return id;
    final earlier = _earlierBlock(
      old,
      kind,
      firstLine,
      from: resume.oldLine,
      to: stopOld,
      taken: inherited,
    );
    if (earlier != null) inherited.add(earlier);
    return earlier ?? ids.fresh();
  }

  final replaced = _definitionsFrom(old, from: resume.oldLine, to: stopOld);
  final read = definitionsRead(root);
  final frozen = freezeBlocks(
    root,
    lines,
    newId: newId,
    definitions: old.definitions,
    lineIndex: lineIndex,
  );
  if (!replaced && read.isEmpty) {
    return (root: frozen, definitions: old.definitions, nextBlockId: ids.next);
  }
  final definitions = _byLabel(definitionsIn(frozen));
  if (_sameDefinitions(definitions, old.definitions)) {
    return (root: frozen, definitions: definitions, nextBlockId: ids.next);
  }
  return _readAnew(old, lines, ids.next, planned);
}

/// A whole read of [lines] whose blocks take their [planned] ids, else
/// the ids of [old]'s blocks by kind and first line.
NoteReading _readAnew(
  EarlierReading old,
  List<Line> lines,
  int nextBlockId,
  PlannedIds planned,
) {
  final ids = _Ids(nextBlockId);
  final plan = _Plan(planned);
  final taken = plan.ids;
  final indexes = {for (final (index, line) in lines.indexed) line.id: index};
  final (:root, stoppedAt: _) = readOpenBlocks(
    lines,
    lineIndex: (id) => indexes[id]!,
  );
  final definitions = _byLabel(definitionsRead(root));
  BlockId newId(BlockKind kind, LineId firstLine) {
    if (plan.take(kind, firstLine) case final id?) return id;
    final earlier = _earlierBlock(
      old,
      kind,
      firstLine,
      from: 0,
      to: old.lines.length,
      taken: taken,
    );
    if (earlier != null) taken.add(earlier);
    return earlier ?? ids.fresh();
  }

  return (
    root: freezeBlocks(
      root,
      lines,
      newId: newId,
      definitions: definitions,
      lineIndex: (id) => indexes[id]!,
    ),
    definitions: definitions,
    nextBlockId: ids.next,
  );
}

/// Whether the change from line [start] to [end] of [lines] may start,
/// end or change front matter, which only a whole read finds.
bool _frontMatterMayChange(
  EarlierReading old,
  List<Line> lines,
  int start,
  int end,
) {
  if (old.root.children.firstOrNull case final FrontMatterBlock front) {
    return start <= old.indexOf(front.lines.last.id);
  }
  return lines.isNotEmpty &&
      frontMatterFence.hasMatch(lines.first.text) &&
      (start == 0 ||
          lines
              .sublist(start, end)
              .any((line) => frontMatterEnd.hasMatch(line.text)));
}

/// Where a re-read of a change at line [start] resumes: at the last line
/// before it that starts a block, with that block's containers open; at
/// the top (after front matter, which never goes on) if none does.
({ResumePoint point, int oldLine}) _resumePoint(EarlierReading old, int start) {
  for (var index = start - 1; index >= 0; index--) {
    final starts = old.startsAt(old.lines[index].id);
    if (starts.isEmpty) continue;
    final (:block, :path) = starts.first;
    if (block is FrontMatterBlock) break;
    return (
      point: (
        line: index,
        open: [
          for (final (level, container) in path.indexed)
            (
              container: container,
              kept: container.children
                  .takeWhile(
                    (child) =>
                        child.id !=
                        (level + 1 < path.length ? path[level + 1] : block).id,
                  )
                  .toList(),
            ),
        ],
      ),
      oldLine: index,
    );
  }
  final front = [...old.root.children.whereType<FrontMatterBlock>()];
  final line = front.isEmpty ? 0 : old.indexOf(front.single.lines.last.id) + 1;
  return (
    point: (line: line, open: [(container: old.root, kept: front)]),
    oldLine: line,
  );
}

/// The earlier reading's blocks after the changed lines, where the new
/// reading may line up with it again.
final class _Stops implements StopPoints {
  _Stops(this._old, this._shift, {required this.from});

  final EarlierReading _old;
  final int _shift;

  @override
  final int from;

  @override
  OldStart? startAt(int index) {
    final oldIndex = index - _shift;
    if (oldIndex >= _old.lines.length) return null;
    final starts = _old.startsAt(_old.lines[oldIndex].id);
    if (starts.isEmpty) return null;
    final (:block, :path) = starts.first;
    return (
      block: block,
      path: path,
      rests: [
        for (final (level, container) in path.indexed)
          if (level + 1 < path.length)
            container.children
                .skipWhile((child) => child.id != path[level + 1].id)
                .skip(1)
                .toList()
          else
            container.children
                .skipWhile((child) => child.id != block.id)
                .toList(),
      ],
    );
  }
}

/// The id of [old]'s block of [kind] that starts at line [firstLine],
/// between lines [from] and [to], unless [taken].
BlockId? _earlierBlock(
  EarlierReading old,
  BlockKind kind,
  LineId firstLine, {
  required int from,
  required int to,
  required Set<BlockId> taken,
}) {
  final blocks = old.firstAt(firstLine);
  if (blocks.isEmpty) return null;
  final index = old.indexOf(firstLine);
  if (index < from || index >= to) return null;
  return blocks
      .firstWhereOrNull(
        (block) => BlockKind.of(block) == kind && !taken.contains(block.id),
      )
      ?.id;
}

/// Whether [old] has link definitions starting between lines [from] and
/// [to].
bool _definitionsFrom(
  EarlierReading old, {
  required int from,
  required int to,
}) {
  for (var index = from; index < to; index++) {
    final starts = old.startsAt(old.lines[index].id);
    if (starts.any((start) => start.block is DefinitionsBlock)) return true;
  }
  return false;
}

/// The link definitions in [block], in file order.
Iterable<LinkDefinition> definitionsIn(Block block) => switch (block) {
  ContainerBlock(:final children) => children.expand(definitionsIn),
  DefinitionsBlock(:final definitions) => definitions,
  _ => const [],
};

/// [definitions] by normalized label; the first of a label counts.
Map<String, LinkDefinition> _byLabel(Iterable<LinkDefinition> definitions) {
  final byLabel = <String, LinkDefinition>{};
  for (final definition in definitions) {
    byLabel.putIfAbsent(normalizeLabel(definition.label), () => definition);
  }
  return byLabel;
}

bool _sameDefinitions(
  Map<String, LinkDefinition> a,
  Map<String, LinkDefinition> b,
) =>
    a.length == b.length &&
    a.entries.every((entry) => b[entry.key] == entry.value);

/// Hands out planned ids in order; [ids] are all of them, which no
/// other block may take.
final class _Plan {
  _Plan(PlannedIds planned)
    : _left = {
        for (final MapEntry(:key, :value) in planned.entries) key: [...value],
      },
      ids = {for (final ids in planned.values) ...ids};

  final Map<(BlockKind, LineId), List<BlockId>> _left;
  final Set<BlockId> ids;

  BlockId? take(BlockKind kind, LineId firstLine) =>
      switch (_left[(kind, firstLine)]) {
        final left? when left.isNotEmpty => left.removeAt(0),
        _ => null,
      };
}

/// Hands out fresh block ids.
final class _Ids {
  _Ids(this.next);

  int next;

  BlockId fresh() => BlockId(next++);
}
