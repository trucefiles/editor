# Truce Editor

A peer-to-peer text editor that works natively with Syncthing.

## License

GPL-3.0. See [LICENSE](LICENSE).

## Development

A Dart pub workspace with three packages:

- `core`: files, sync-tool rules and conflict handling. Pure Dart, no UI.
- `app`: the Flutter app (Android, Linux). Uses only `core`.
- `lints`: analyzer and lint settings shared by all packages.

Needs Flutter 3.47.7. From the repository root:

```sh
flutter pub get --enforce-lockfile
dart format .
flutter analyze --fatal-infos
(cd core && dart test)
(cd app && flutter test)
```
