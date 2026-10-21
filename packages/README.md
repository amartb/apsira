# Apsira shared packages

Three Dart packages every Apsira Flutter app depends on. Decided in `../docs/decisions.md`
D-APK-001 (set and boundaries), D-APK-002 (tools scope) and D-APK-003 (pinning).

| Package | Kind | Holds | Depends on |
|---|---|---|---|
| `apsira_core` | pure Dart | `Result`/`Failure`, the log model, the `Clock` and `IdGen` ports, `testing/fake_clock.dart` | nothing |
| `apsira_ui` | Flutter | `ApsiraTheme` tokens, `ApsiraThemeData.build`, typography, shape, chrome icons, fonts, lockup, licences, provenance | `flutter`, `flutter_lucide`, `apsira_core` |
| `apsira_tools` | pure Dart, `bin/` | `layering_lint`, `l10n_check`, `coverage_gate`, `deps_check`, `manifest_check` + `tool/apsira_tools.yaml` config | `yaml`, `args` |

Source: RELAY commit `5f606e9` (`v1.0.0`). Every extracted file names its origin in a
header comment (`// From relay lib/app/theme/relay_theme.dart @ 5f606e9`).

## Consuming (D-APK-003)

```yaml
dependencies:
  apsira_core:
    git: { url: git@github.com:amartb/apsira.git, ref: apsira_core-v0.1.0, path: packages/apsira_core }
  apsira_ui:
    git: { url: git@github.com:amartb/apsira.git, ref: apsira_ui-v0.1.0, path: packages/apsira_ui }
dev_dependencies:
  apsira_tools:
    git: { url: git@github.com:amartb/apsira.git, ref: apsira_tools-v0.1.0, path: packages/apsira_tools }
```

Co-development only, never committed: `pubspec_overrides.yaml` with
`dependency_overrides: { apsira_ui: { path: ../apsira/packages/apsira_ui } }`.

In the app:

```dart
// lib/app/theme/<app>_theme.dart — the only per-app theme file
final theme = ApsiraThemeData.build(ApsiraTheme.dark, extensions: [MyAppRoles.dark]);
Image(image: ApsiraBrand.lockupReversed);                 // first open / About
dart run apsira_tools:layering_lint --config tool/apsira_tools.yaml
```

## Releasing a package

1. Bump `version:` in its `pubspec.yaml`; add a `CHANGELOG.md` section naming any
   migration a consumer must make.
2. `tool/check.sh` green (analyze + tests for every package; version equals the tag it
   is about to get; `sha256sum -c` of fonts and lockup against `../apsira-brand/`).
3. Tag `apsira_<pkg>-vX.Y.Z` on the commit; push the commit and the tag (operator act).
4. Consumers move their `ref:` in their own session.

## Rules

- Never `build_runner` in a package.
- A package requires the lowest Flutter any live consumer pins.
- Colour literals exist only in `apsira_ui/lib/src/colors.dart`.
- Brand files are copied unchanged from `../apsira-brand/`; the provenance test fails on
  any byte difference.
