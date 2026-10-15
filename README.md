# Truce Editor

A peer-to-peer text editor that works natively with Syncthing.

## License

GPL-3.0. See [LICENSE](LICENSE).

## Development

A Dart pub workspace with four packages:

- `core`: files, sync-tool interfaces and conflict handling. Pure Dart, no
  UI, nothing specific to one sync tool.
- `syncthing`: Syncthing's conventions behind core's interfaces. Pure Dart.
- `app`: the Flutter app (Android, Linux). Uses only `core` and, in its
  sync-tool wiring, `syncthing`.
- `lints`: analyzer and lint settings shared by all packages.

Needs Flutter 3.47.7. From the repository root:

```sh
flutter pub get --enforce-lockfile
dart format .
flutter analyze --fatal-infos
(cd core && dart test)
(cd syncthing && dart test)
(cd app && flutter test)
```
