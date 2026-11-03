import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What home shows below its filter chips.
enum HomeView {
  /// The pinned and the newest files.
  recent,

  /// Every file, sorted and laid out as the home settings say.
  all,
}

/// The view home shows, for this app run only: it always starts in
/// Recent, which stays fast with large folders.
final homeViewProvider = NotifierProvider<HomeViewChoice, HomeView>(
  HomeViewChoice.new,
);

class HomeViewChoice extends Notifier<HomeView> {
  @override
  HomeView build() => HomeView.recent;

  void show(HomeView view) => state = view;
}
