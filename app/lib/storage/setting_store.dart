/// Where one setting of this device is kept. Saves land in the order they
/// are made (the setting's file writes one at a time); a failed save
/// leaves the saved value as it was.
abstract interface class SettingStore<T> {
  /// The saved value; a default if none or unreadable.
  Future<T> load();

  Future<void> save(T value);
}
