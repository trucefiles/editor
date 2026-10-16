# Truce Editor

Notes and checklists in plain Markdown files, in folders you share with
Syncthing. No server and no account: your files stay on your devices.

- Edit notes as text, as a checklist, or read them rendered.
- When two devices change the same note, see both versions side by side and
  pick one. Nothing is merged or dropped behind your back.
- Changes only what you edit, byte for byte; keeps 7 days of backups.
- Android and Linux (Flatpak).

Early development (0.x): expect changes between versions.

## Install

Download the APK or the Flatpak from the
[latest release](https://github.com/trucefiles/editor/releases/latest).
Check the download against `SHA256SUMS` from the same release. The APK is
signed with the key whose certificate SHA-256 is in
[`app/android/release-certificate-sha256.txt`](app/android/release-certificate-sha256.txt).

```sh
sha256sum --check --ignore-missing SHA256SUMS
flatpak install --user truce-editor-vX.Y.Z.flatpak
```

## Known limitations

See [docs/known-limitations.md](docs/known-limitations.md).

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md). Please report security issues
privately, as described in [SECURITY.md](SECURITY.md).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

## Development

A Dart pub workspace with five packages:

- `core`: files, sync-tool interfaces and conflict handling. Pure Dart, no
  UI, nothing specific to one sync tool.
- `syncthing`: Syncthing's conventions behind core's interfaces. Pure Dart.
- `app`: the Flutter app (Android, Linux). Uses only `core` and, in its
  sync-tool wiring, `syncthing`.
- `test_support`: test doubles shared by the packages' tests (a fake sync
  tool, an in-memory file store). Only a dev dependency.
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
