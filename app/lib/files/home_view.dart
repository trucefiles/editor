import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What home shows below its filter chips.
enum HomeView {
  /// Home: the pinned files and the recently edited ones.
  home,

  /// Every file, sorted and laid out as the home settings say.
  all,
}

/// The view home shows, for this app run only: it always starts in
/// Home, which stays fast with large folders.
final homeViewProvider = NotifierProvider<HomeViewChoice, HomeView>(
  HomeViewChoice.new,
);

class HomeViewChoice extends Notifier<HomeView> {
  @override
  HomeView build() => HomeView.home;

  void show(HomeView view) => state = view;
}
