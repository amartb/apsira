# Building on Alejandro's computer

What is installed once on amb811, how a dev APK reaches the phone, how the hub runs during development, and how a
release is built. Adapted from ASTROLABE's `docs/building.md`. Checks and the dev APK run in the Claude Code
session; a release runs only outside one (`release-signing.md`). Installing the real hub is the operator's, by
`10-hub-runbook.md`.

## 1. One-time installs (already on amb811, under `~/sdk/`, unless marked)

| Tool | Why | Check |
|---|---|---|
| Flutter 3.47.7 (with its Dart SDK) | the app, and the hub compiled with `dart compile exe` | `flutter --version` |
| JDK 17 | Gradle, Robolectric; `keytool` for the release key | `"$JAVA_HOME/bin/java" -version` |
| Android SDK (`ANDROID_HOME`) | the build; `apksigner` for the release check and for recording fingerprints | `"$ANDROID_HOME"/build-tools/*/apksigner --version` |
| `gh` | the private release | `gh auth status` |
| restic, rest-server (slice 2; operator installs, `10-hub-runbook.md`) | the snapshot store | `restic version` |

## 2. A dev APK

Built by the conductor once per slice, as the siblings' `tool/build_apk.sh` (apsira_tools' skeleton): `--flavor dev`
(`com.apsiralabs.apsira.dev`, "APSIRA dev"), the merged prod manifest checked against the declared permission list
(D-024 with D-029: `INTERNET` and `CAMERA` declared, no location, no notification listener), the APK's path and SHA-256 printed. It reads no
key. The APK and its `.sha256` are copied to `~/projects/apsira-builds/`. A dev APK is never an RC: RCs are built and
signed by the release script outside any session (D-035), and the shelf never offers a dev or debug-signed APK.

**A dev APSIRA pairs only with a dev hub** (D-027). It trusts dev builds by package name only, in dev-flavour
source (`contracts/app-link.md` §3.3); it never pairs with the real hub, and a release APSIRA never trusts a dev app
or any debug certificate (D-031).

## 3. The hub during development

Hub code is exercised by tests against scratch directories and fakes (`08`, `agent-rules.md`). When a slice needs
a running hub on this machine for a device check, it runs as the session user on a scratch area and a loopback or
LAN port the runbook names for development, never as the `apsira` account and never on the real store. The real
hub is installed and upgraded only by the operator, following `10-hub-runbook.md`.

## 4. Installing on the phone

Until slice 1's release, as ASTROLABE's `building.md` §3: from `~/projects/apsira-builds/`, checked with
`sha256sum`, by wireless `adb install -r` or from *My Files*. From slice 1 on, APSIRA updates itself from its own
shelf (D-007): an RC the release script signed appears there, marked.

## 5. Release

Only on Alejandro's computer, outside any Claude Code session, by the release script (D-025,
`release-signing.md`). It refuses inside a session.
