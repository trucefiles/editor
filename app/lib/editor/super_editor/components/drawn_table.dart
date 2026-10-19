import 'package:flutter/material.dart';

/// A Markdown table drawn as a grid: the header's cells, then each row's.
/// A tap shows its lines to edit them.
class DrawnTable extends StatelessWidget {
  const DrawnTable(this.rows, {this.onTap, super.key});

  final List<List<String>> rows;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = rows.fold(
      0,
      (most, row) => row.length > most ? row.length : most,
    );
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
      children: [
        for (var i = 0; i < columns; i++)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              i < cells.length ? cells[i] : '',
              style: header
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: theme.colorScheme.outlineVariant),
          children: [
            if (rows.isNotEmpty) row(rows.first, header: true),
            for (final cells in rows.skip(1)) row(cells),
          ],
        ),
      ),
    );
  }
}
