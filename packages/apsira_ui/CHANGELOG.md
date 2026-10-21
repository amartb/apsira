# apsira_ui changelog

One section per tag (`apsira_ui-vX.Y.Z`), naming any migration a consumer must make.

## 0.1.0 — 2026-10-21

First release: RELAY's theme at `5f606e9` (`v1.0.0`) as a package (D-APK-001).

**Migration (the RELAY → Apsira shims).** An app that carried RELAY's theme adopts by
renaming, or by typedef shims (`typedef RelayTheme = ApsiraTheme;`):
`RelayTheme` → `ApsiraTheme`, `RelayThemeData` → `ApsiraThemeData`, `RelayFamily` →
`ApsiraFamily`, `RelayFamilyColors` → `ApsiraFamilyColors`, `RelayLightColors` /
`RelayDarkColors` → `ApsiraLightColors` / `ApsiraDarkColors`, `RelayFonts` →
`ApsiraFonts`, `RelayTypeStyle` → `ApsiraTypeStyle`, `RelayTypography` →
`ApsiraTypography`, `RelayRadii` / `RelaySizes` / `RelaySpacing` / `RelayShapes` →
`ApsiraRadii` / `ApsiraSizes` / `ApsiraSpacing` / `ApsiraShapes`, `AppIcons`' chrome
constants → `ApsiraIcons`, `registerFontLicences()` + `registerIconLicences()` →
`ApsiraBrand.registerLicences()`. The app then drops its own `fonts:` block, font and
licence assets and lockup copy: the package bundles them.

**What differs from RELAY's files.**
- Every `TextStyle` carries `package: 'apsira_ui'`, so its `fontFamily` reads
  `packages/apsira_ui/Archivo` (and so on); `ApsiraFonts` keeps the bare names and adds
  `*Qualified`. A test comparing a style's family with the bare name compares with the
  qualified one.
- `ApsiraThemeData.build(tokens, {extensions})` attaches an app's own extensions after
  the tokens.
- `ApsiraIcons` holds only the nine chrome glyphs; the stored-icon registry stays in the app.
- The Material mapping's two fixed values live in `colors.dart` as `ApsiraSchemeColors`.
- Assets sit under `lib/` (`lib/fonts/`, `lib/brand/`, `lib/licenses/`), bytes unchanged.

**RELAY test groups not carried** (they test RELAY's documents or app code):
`the table above matches UX §2.2 itself` and `the constants cover UX §2.4 itself`
(the tables are the tests' own constants, copied from RELAY `docs/06` @ `5f606e9`);
`app_icons_test.dart`'s registry tests (ids, value types, picker, fallback). The picker
dialog tests open Flutter's `showDatePicker` / `showTimePicker` instead of RELAY's editors.
