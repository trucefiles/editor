import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// A Markdown [table] drawn as a grid: the header's cells, then each
/// row's, lined up as its columns say. A tap shows its text to edit it.
class DrawnTable extends StatelessWidget {
  const DrawnTable(this.table, {this.onTap, super.key});

  final TableBlock table;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
      children: [
        for (final (index, cell) in cells.indexed)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              cell,
              textAlign: _textAlign(table.alignments[index]),
              style: header
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
      ],
    );
    final rows = table.rows;
    return GestureDetector(
      onTap: onTap,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: theme.colorScheme.outlineVariant),
          children: [
            row(rows.first, header: true),
            for (final cells in rows.skip(1)) row(cells),
          ],
        ),
      ),
    );
  }

  static TextAlign _textAlign(CellAlignment alignment) => switch (alignment) {
    CellAlignment.none || CellAlignment.left => TextAlign.left,
    CellAlignment.center => TextAlign.center,
    CellAlignment.right => TextAlign.right,
  };
}
