import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// The image of an image line: a web image is loaded, others show their
/// alt text. A tap shows the line to edit it.
class DrawnImage extends StatelessWidget {
  const DrawnImage(this.entry, {this.onTap, super.key});

  final ImageEntry entry;
  final VoidCallback? onTap;

  bool get _isWeb {
    final scheme = Uri.tryParse(entry.url)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    final alt = Text(
      entry.alt.isEmpty ? entry.url : entry.alt,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    return GestureDetector(
      onTap: onTap,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _isWeb
            ? Image.network(
                entry.url,
                semanticLabel: entry.alt,
                errorBuilder: (_, _, _) => alt,
              )
            : alt,
      ),
    );
  }
}
