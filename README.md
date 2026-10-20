<p align="center">
  <img src="app/linux/flatpak/io.github.trucefiles.editor.svg" width="96" alt="Truce Editor icon">
</p>

<h1 align="center">Truce Editor</h1>

<p align="center">
  Your notes and checklists, shared between your devices and people,<br>
  with no server in the middle.
</p>

<p align="center">
  <img src="docs/images/screenshot.png" width="720" alt="Truce Editor showing a grid of notes and checklists">
</p>

## Why Truce

- **No central server.** Devices sync directly with each other, peer to
  peer, through [Syncthing](https://syncthing.net). There's no account to
  create and no cloud to trust: your files stay on your devices.
- **Works on any network, even offline.** Each device syncs with whichever
  others it can reach right now: at home, across the internet, or just over
  a private network or a phone's hotspot with no internet at all. As
  devices come and go, editing carries on.
- **Conflicts are caught, never lost.** When two devices change the same
  note at once, Truce notices, shows both versions side by side and lets
  you choose. Nothing is overwritten behind your back, and backups
  of the last 7 days let you go back.
- **Plain files you own.** Notes are ordinary Markdown files in your own
  folders. Truce changes only what you edit, byte for byte, so they stay
  readable by any other app.
- **Built on a trusted sync tool.** Syncthing does the syncing; Truce
  focuses on editing and conflicts. Support for other sync tools can follow.

## What it does today

- Notes and checklists, edited as text, as a checklist, or read rendered.
- As many folders as you like, subfolders included, each shared with its
  own devices and people: say one for you and one for the family shopping.
- Search, pins and colors across all of them.
- Android and Linux (Flatpak).

## What's coming

- Assisted merge: Truce suggests a merged version of a conflict for you to
  accept.
- More kinds of files beyond notes and checklists.
- Windows, macOS and iOS.

Truce is in early development (0.x), so expect changes between versions.

## Install

Grab the APK (Android) or the Flatpak (Linux) from the
[latest release](https://github.com/trucefiles/editor/releases/latest).
You need Syncthing running on your devices, with a shared folder for your
notes.

To check a download, compare it with `SHA256SUMS` from the same release.
The APK is signed with the key whose certificate SHA-256 is in
[`app/android/release-certificate-sha256.txt`](app/android/release-certificate-sha256.txt).

```sh
sha256sum --check --ignore-missing SHA256SUMS
flatpak install --user truce-editor-vX.Y.Z.flatpak
```

On Linux, `--background` starts Truce in the tray, e.g. at login, when
"Keep running in tray" is on in Settings:

```sh
flatpak run io.github.trucefiles.editor --background
```

## Markdown support

See [docs/markdown.md](docs/markdown.md) for what Truce follows from the
Markdown standard and where it differs.

## Known limitations

See [docs/known-limitations.md](docs/known-limitations.md).

## Contributing and security

Ideas, bug reports and pull requests are welcome: see
[CONTRIBUTING.md](CONTRIBUTING.md). Found a security issue? Please report
it privately, as described in [SECURITY.md](SECURITY.md).

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
