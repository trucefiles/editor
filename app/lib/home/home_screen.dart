import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar_tab/calendar_tab_controller.dart';
import '../calendar_tab/ui/calendar_tab_screen.dart';
import '../documents/ui/documents_screen.dart';

/// The app's home: the documents, and once the shown folders hold a
/// calendar, a Calendar tab beside them.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;

  /// The same tree with and without the tab, so the documents keep their
  /// state when a calendar comes or goes.
  @override
  Widget build(BuildContext context) {
    // Once the last calendar goes, the tab is gone: a calendar coming back
    // later shows the documents still.
    ref.listen(hasCalendarsProvider, (_, calendars) {
      if (!calendars) setState(() => _tab = 0);
    });
    final calendars = ref.watch(hasCalendarsProvider);
    final tab = calendars ? _tab : 0;
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          const DocumentsScreen(),
          if (calendars) const CalendarTabScreen() else const SizedBox(),
        ],
      ),
      bottomNavigationBar: calendars
          ? NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (tab) => setState(() => _tab = tab),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  label: 'Documents',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Calendar',
                ),
              ],
            )
          : null,
    );
  }
}
