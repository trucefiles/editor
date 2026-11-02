import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// How the app searches files: by reading their texts while search is
/// open.
final openTextSearchProvider = Provider<OpenTextSearch<ListedFile>>(
  (ref) => ReadingSearch.new,
);
