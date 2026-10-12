import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app may open folders by path. Android needs the all-files
/// permission for that; other platforms grant access per picked folder.
abstract interface class StorageAccess {
  Future<bool> isGranted();

  /// Opens the system page where the user grants access. The answer comes
  /// back later; check [isGranted] again when the app is shown.
  Future<void> request();
}

/// Android: all-files access, asked for through `MainActivity`.
final class AndroidStorageAccess implements StorageAccess {
  const AndroidStorageAccess();

  static const _channel = MethodChannel(
    'io.github.trucefiles.editor/storage_access',
  );

  @override
  Future<bool> isGranted() async =>
      await _channel.invokeMethod<bool>('hasAccess') ?? false;

  @override
  Future<void> request() => _channel.invokeMethod<void>('requestAccess');
}

/// Platforms where picking a folder is enough.
final class GrantedStorageAccess implements StorageAccess {
  const GrantedStorageAccess();

  @override
  Future<bool> isGranted() async => true;

  @override
  Future<void> request() async {}
}

final storageAccessProvider = Provider<StorageAccess>(
  (ref) => Platform.isAndroid
      ? const AndroidStorageAccess()
      : const GrantedStorageAccess(),
);
