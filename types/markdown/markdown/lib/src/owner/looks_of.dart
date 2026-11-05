import '../doc/doc_nodes.dart';
import '../edit/selection.dart';
import '../view/add_item_place.dart';
import '../view/row_looks.dart';
import 'editor_contract.dart';

/// The looks of what Visual edit shows of [shown]: its block selected
/// whole and its open raw block as [shown] has them; the boxes of the
/// items in [waiting] flipped, Add item buttons at [addItems], the
/// subitems of [folded] hidden (see [RowLooks]).
List<RowLook> looksOf(
  FormattedContent shown, {
  Set<NodeId> waiting = const {},
  AddItemPlace? addItems,
  NodeId? folded,
}) => RowLooks(
  shown.view,
  selected: switch (shown.selection) {
    BlockSelection(:final block) => block,
    _ => null,
  },
  raw: switch (shown.raw) {
    RawRegion(:final block, :final text) => (block: block, text: text),
    null => null,
  },
  waiting: waiting,
  addItems: addItems,
  folded: folded,
).looks;
