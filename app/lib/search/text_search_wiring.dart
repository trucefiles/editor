import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

/// How the app searches documents: by reading their texts while search is
/// open.
final openTextSearchProvider = Provider<OpenTextSearch<Document>>(
  (ref) => ReadingSearch.new,
);
