# Apsira shared packages

Three Dart packages every Apsira Flutter app depends on. Decided in `../docs/decisions.md`
D-APK-001 (set and boundaries), D-APK-002 (tools scope), D-APK-003 (pinning) and
D-APK-006 (what v0.1 settled: no package depends on another, the fonts layout,
`--l10n-config`).

| Package | Kind | Holds | Depends on |
|---|---|---|---|
| `apsira_core` | pure Dart | `Result`/`Failure`, the log model, the `Clock` and `IdGen` ports; `testing.dart` with `FakeClock` and `FakeIdGen` | nothing |
| `apsira_ui` | Flutter | `ApsiraTheme` tokens, `ApsiraThemeData.build`, typography, shape, chrome icons, fonts, lockup, licences, provenance; `example/`, the consumer proof | `flutter`, `flutter_lucide` |
| `apsira_tools` | pure Dart, `bin/` | `layering_lint`, `l10n_check`, `coverage_gate`, `deps_check`, `manifest_check` + `tool/apsira_tools.yaml` config | `yaml` |

No package depends on another in v0.x (D-APK-006): an app pins each one it uses by its
own tag. Each library is imported through its barrel (`package:apsira_core/apsira_core.dart`,
`package:apsira_core/testing.dart`, `package:apsira_ui/apsira_ui.dart`); `src/` is private.
`apsira_ui/example/` is an app that depends on `apsira_ui` as a consumer does; its tests
prove the package-qualified fonts, licences and lockup load from a consumer's bundle.

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
```

```sh
dart run apsira_tools:layering_lint --config tool/apsira_tools.yaml
dart run apsira_tools:l10n_check --l10n-config lib/app/l10n/l10n.yaml
```

Every tool takes `--config` (the tools file). `l10n_check` names its gen-l10n file
`--l10n-config`, where RELAY's copy said `--config` (D-APK-006).

## Releasing a package

1. Bump `version:` in its `pubspec.yaml`; add a `CHANGELOG.md` section naming any
   migration a consumer must make.
2. `bash tool/check.sh` ends with `check: PASS`. It runs every step even after a failure,
   printing `ok <step>` or `FAIL <step>`: `sha256sum -c` of `apsira_ui/lib/fonts` and
   `lib/brand`, `cmp` of the fonts and the lockup against `../apsira-brand/`, colour
   literals only in `colors.dart`, `dart format`; per package the `version:` has its
   `CHANGELOG.md` section and, when the tag `apsira_<pkg>-v<version>` already exists,
   the pubspec at that tag carries the same version; then `pub get`, analyze and tests
   for each package and for `apsira_ui/example/` (from a clean `build/`).
3. Tag `apsira_<pkg>-vX.Y.Z` on the commit; push the commit and the tag (operator act).
4. Consumers move their `ref:` in their own session.

## Rules

- Never `build_runner` in a package.
- A package requires the lowest Flutter any live consumer pins.
- Colour literals exist only in `apsira_ui/lib/src/colors.dart`.
- Brand files are copied unchanged from `../apsira-brand/`; the provenance test fails on
  any byte difference.
