import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// A component that passes positions and text on to the text component it
/// builds with [childTextKey].
mixin ChildText<T extends StatefulWidget>
    on ProxyDocumentComponent<T>, ProxyTextComposable {
  final childTextKey = GlobalKey();

  @override
  GlobalKey get childDocumentComponentKey => childTextKey;

  @override
  TextComposable get childTextComposable =>
      childTextKey.currentState! as TextComposable;
}
