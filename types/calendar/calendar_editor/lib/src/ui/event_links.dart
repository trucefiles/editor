import 'package:flutter/widgets.dart';

/// What the app gives to open what an event's text points to: a web or
/// mail link ([openLink]) and a place, in a maps app ([openPlace]); each
/// `false` if nothing could open it.
final class EventOpeners {
  const EventOpeners({required this.openLink, required this.openPlace});

  final Future<bool> Function(Uri link) openLink;
  final Future<bool> Function(String place) openPlace;
}

/// How the event sheets opened below it open links and places: with
/// [openers], [hint] saying when nothing could. A sheet takes it from
/// where it opens; without one, links and places show as plain text.
class EventLinks extends InheritedWidget {
  const EventLinks({
    required this.openers,
    required this.hint,
    required super.child,
    super.key,
  });

  final EventOpeners openers;
  final void Function(String message) hint;

  static EventLinks? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EventLinks>();

  Future<void> openLink(Uri link) async {
    if (!await openers.openLink(link)) hint('No app could open $link');
  }

  Future<void> openPlace(String place) async {
    if (!await openers.openPlace(place)) hint('No app could show $place');
  }

  @override
  bool updateShouldNotify(EventLinks oldWidget) =>
      openers != oldWidget.openers || hint != oldWidget.hint;
}
