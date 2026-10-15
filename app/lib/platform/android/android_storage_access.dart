import 'package:flutter/services.dart';

import '../storage_access.dart';

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
