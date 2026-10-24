# Apsira shared packages

Six Dart packages the Apsira Flutter apps depend on, released together at one shared tag
`apsira-vX.Y.Z`. Decided in `../docs/decisions.md`: D-APK-001 (the first set and its
boundaries), D-APK-002 (tools scope), D-APK-003 (pinning by git ref), D-APK-006 (what v0.1
settled), D-APK-007 (one version, one tag, edges between packages), D-APK-009 (adoption in
every app) and D-APK-011 (the Tier-1 set at `apsira-v0.2.0`).

| Package | Kind | Holds | Depends on |
|---|---|---|---|
| `apsira_core` | pure Dart | `Result`/`Failure`, the log model with `stackHash`, the `Clock` and `IdGen` ports with the monotonic UUIDv7, the FTS5 match builder, canonical JSON; `testing.dart` with `FakeClock` and `FakeIdGen` | `crypto` |
| `apsira_ui` | Flutter | `ApsiraTheme` tokens, `ApsiraThemeData.build`, typography, shape, chrome icons, fonts, lockup, licences, provenance; `example/`, the consumer proof | `flutter`, `flutter_lucide` |
| `apsira_tools` | pure Dart, `bin/` | `layering_lint`, `l10n_check`, `coverage_gate`, `deps_check`, `manifest_check` + `tool/apsira_tools.yaml` config; the release and build script skeletons | `yaml` |
| `apsira_test` | Flutter, dev | the Android font scaler, the large-text layout checker, the golden matrix with bundled fonts, the a11y pass, `prop_core`, pump helpers | `flutter`, `flutter_test`, `apsira_ui` |
| `apsira_app` | Flutter plugin | error handlers, the rotating file log sink, the start-phase redirect, `RestartableRoot`, the startup-failure app, `SystemClock` + the zone channel, per-install flags, the About page | `flutter`, `apsira_core`, `apsira_ui` |
| `apsira_jobs` | Flutter plugin | the `BackgroundJobs` port, `JobConstraints`, the WorkManager adapter (keep/replace policy) and its fake, the zone-change resync receiver (`ZoneResync.kt`); RELAY and VIATICUM only | `flutter`, `workmanager` |

Each library is imported through its barrel (`package:apsira_core/apsira_core.dart`,
`package:apsira_core/testing.dart`, `package:apsira_ui/apsira_ui.dart`, …); `src/` is private.
`apsira_ui/example/` is an app that depends on `apsira_ui` as a consumer does; its tests
prove the package-qualified fonts, licences and lockup load from a consumer's bundle.

Every extracted file names its source app, path and commit in a header comment
(`// From relay lib/app/theme/relay_theme.dart @ 5f606e9`); v0.2 extracts from RELAY
`09b28810`, VIATICUM `78d38e0` and LYCEUM `9f4ff27`.

## Consuming

An app pins every apsira package it uses at the same shared tag:

```yaml
dependencies:
  apsira_core: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.2.0, path: packages/apsira_core } }
  apsira_ui: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.2.0, path: packages/apsira_ui } }
  apsira_app: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.2.0, path: packages/apsira_app } }
dev_dependencies:
  apsira_tools: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.2.0, path: packages/apsira_tools } }
  apsira_test: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.2.0, path: packages/apsira_test } }
```

Co-development only, never committed in an app: a gitignored `pubspec_overrides.yaml`
with a path override for every apsira package in the app's closure,
`dependency_overrides: { apsira_ui: { path: ../apsira/packages/apsira_ui }, … }`.

In the app:

```dart
// lib/app/theme/<app>_theme.dart — the only per-app theme file
final theme = ApsiraThemeData.build(ApsiraTheme.dark, extensions: [MyAppRoles.dark]);
Image(image: ApsiraBrand.lockupReversed);                 // first open / About
```

```sh
dart run apsira_tools:layering_lint --config tool/apsira_tools.yaml
dart run apsira_tools:l10n_check --l10n-config lib/app/l10n/l10n.yaml
```

Every tool takes `--config` (the tools file). `l10n_check` names its gen-l10n file
`--l10n-config`, where RELAY's copy said `--config` (D-APK-006).

## Dependencies between packages (D-APK-007)

A package may depend on another, in exactly this one-line form, at the shared tag of
its own version:

```yaml
dependencies:
  apsira_core: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.2.0, path: packages/apsira_core } }
```

and commits `pubspec_overrides.yaml` with a path override for the transitive closure of
its apsira dependencies, and nothing else:

```yaml
dependency_overrides:
  apsira_core: { path: ../apsira_core }
```

The override applies only when the package is the root, so inside this repository it
resolves against its siblings, offline and before the tag exists; consumers never see
it. A `path:` dependency is a defect. `bash tool/check.sh --release` checks the rules.

## Releasing

One version, one tag, for every package:

1. Set the same `version:` in every `packages/*/pubspec.yaml`, and add a
   `## X.Y.Z — <date>` section to every `CHANGELOG.md`, naming any migration a consumer
   must make ("no change in behaviour" for a package that did not change).
2. `bash tool/check.sh` ends with `check: PASS`. It runs every step even after a failure,
   printing `ok <step>` or `FAIL <step>`: the shared-tag rules (equal versions, each
   CHANGELOG section, a tag that exists carries that version in every package, every
   apsira dependency in the exact git form at `apsira-v<version>`, every override file
   the transitive closure), `sha256sum -c` of `apsira_ui/lib/fonts` and `lib/brand`,
   `cmp` of the fonts and the lockup against `../apsira-brand/`, colour literals only in
   `colors.dart`, `dart format`; then `pub get`, analyze and tests for every package and
   every `example/` (from a clean `build/`).
3. Merge to `main` and push it. Then, on the operator's computer, `bash tool/release.sh`
   (`--dry-run` first): it refuses in a session, requires a clean `main` equal to
   `origin/main`, equal versions and an absent tag, runs `tool/check.sh` itself, tags
   `apsira-vX.Y.Z`, pushes the tag and proves a scratch consumer resolves every package
   at it.
4. Each app adopts in its own adoption lane (D-APK-009) by moving its `ref:` lines.

## Rules

- Never `build_runner` in a package.
- A package requires the lowest Flutter any live consumer pins.
- Colour literals exist only in `apsira_ui/lib/src/colors.dart` (checked over every package's `lib/` but `apsira_tools`; tests and fixtures are exempt).
- Brand files match `SHA256SUMS`; those that also exist in `../apsira-brand/` are byte-identical
  to it; the provenance test fails on any difference.
