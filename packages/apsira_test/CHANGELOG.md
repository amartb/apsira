# apsira_test changelog

One section per release, naming any migration a consumer must make. Every package shares
one tag, `apsira-vX.Y.Z` (D-APK-007).

## 0.4.0 — 2026-10-24

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.4.0`.

## 0.3.0 — 2026-10-24

No change in behaviour. Its `apsira_ui` dependency moves to `ref: apsira-v0.3.0`. Migration: move every apsira `ref:` to
`apsira-v0.3.0`.

## 0.2.0 — 2026-10-24

First release: the test support of RELAY `09b28810`, VIATICUM `78d38e0` and LYCEUM
`9f4ff27` in one copy. The layout check is LYCEUM's superset with VIATICUM's `sideways`
check behind `LayoutHost.forbidSideways`. The golden matrix is LYCEUM's with RELAY's
`goldenMatrix`. `prop_core` is RELAY's and VIATICUM's shared engine. The `PROP` variables
are renamed `APSIRA_PROP_SCALE` and `APSIRA_PROP_SEED`.

**Migration for RELAY** (`test/support/`):
- `android_font_scaler.dart` → `AndroidFontScaler`, same tables.
- `golden/relay_golden.dart` → `GoldenVariant`, `goldenVariants`, `goldenApp` and
  `goldenMatrix(…, host: <RELAY's LayoutHost>, scaler: TextScaler.linear)`;
  `loadRelayFonts` → `loadAppFonts`.
- `prop/prop_core.dart` and `prop/prop_core_test.dart` → the package; `prop.dart` exports
  it beside the domain generators, which stay. `.github/workflows/nightly.yml` sets
  `APSIRA_PROP_SCALE` and `APSIRA_PROP_SEED` instead of `RELAY_PROP_*`.
- `test/a11y/key_screens_a11y_test.dart` may call `expectAccessible`.
  `tokens_contrast_test.dart` keeps only its `onSolid` and sixteen-family cases (RELAY's
  tokens); the rest is in apsira_ui.

**Migration for VIATICUM** (`test/support/`):
- `layout/android_font_scale.dart`, `layout/bundled_fonts.dart` → the package.
  `flutter_test_config.dart` calls `loadAppFonts()`.
- `layout/layout_check.dart` → `expectLayoutSound(…, host: LayoutHost(…,
  forbidSideways: true))`. `room: true` becomes a second call whose host's dark theme is
  the room theme. A clip around a scroll view is measured against what the scroll view
  left visible. A `Badge` over its child, the hidden children of an `IndexedStack`, and
  text that a scroll view can carry clear of a floating button are no longer issues
  (LYCEUM's refinements). These changes only remove false failures.
- `golden/viaticum_golden.dart` → `goldenMatrix(…, themeName: (b) => b == Brightness.dark
  ? 'dark' : 'room', size: const Size(390, 844))`, with the room theme in the host's light
  slot; `GoldenSample` stays.
- `prop/prop_core.dart` and `prop/prop_core_test.dart` → the package. `tool/check.sh
  --long` sets `APSIRA_PROP_SCALE=10` instead of `VIATICUM_PROP_SCALE=10`.
- `test/critical/tokens_contrast_test.dart`: apsira_ui now carries the ThemeData
  ColorScheme case. The state roles, the room set and the source scans stay.

**Migration for LYCEUM** (`test/support/`):
- `layout/android_font_scale.dart`, `layout/layout_check.dart`, `layout/bundled_fonts.dart`
  → the package. The `LayoutHost` default theme is apsira_ui's, so LYCEUM passes
  `LyceumTheme`. `test/critical/layout_check_controls_test.dart` goes; its controls are
  `test/layout_check_test.dart` here.
- `golden/lyceum_golden.dart` → `GoldenVariant`, `goldenVariants`, `goldenApp(…, host:)`,
  `pumpGolden(…, host:)` and `withShadows`; `loadLyceumFonts` → `loadAppFonts`.
- `pump_lyceum.dart`: `testBothModes` and `unmountLyceum` (now `unmountAndFlush`) →
  the package. `pumpLyceum` keeps its `ProviderScope` and `ModuleTheme`, around
  `pumpApsira` or as it is.
