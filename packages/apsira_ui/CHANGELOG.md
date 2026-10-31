# apsira_ui changelog

One section per release, naming any migration a consumer must make. From 0.2.0 every
package shares one tag, `apsira-vX.Y.Z` (D-APK-007); 0.1.0 was `apsira_ui-v0.1.0`.

## 0.6.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.6.0`.

## 0.5.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.5.0`.

## 0.4.0 — 2026-10-24

Migration: move every apsira `ref:` to `apsira-v0.4.0`. Additive only; no default moves.

- **`EmptyState.actionIcon`** (D-APK-014, F3): the action's glyph before its label, 20 px.
- **`EmptyState`'s second action**: `secondaryActionLabel`, `onSecondaryAction`,
  `secondaryActionKey`, a tonal pill under the first.
- **`EmptyState.inline`** (D-APK-014, F3): RELAY's cardless empty state (`lib/app/theme/empty_state.dart`
  @ `09b28810`), a bordered `tint` block with its icon tile, the line in `ink2` and an
  `accentText` text button; keys `EmptyState.blockKey`, `EmptyState.iconTileKey`. Migration for
  RELAY: `EmptyState(line:, action:)` becomes `EmptyState.inline(title:, actionLabel:)`. No
  golden moves.

## 0.3.0 — 2026-10-24

The theme carries the shared component themes; settings rows, menu items and the
theme-mode setting join the package (D-APK-013), then the component kit and the
ThemePreview (D-APK-014). New dependencies: `flutter_riverpod ^3.1.0` and `apsira_l10n`
(git form, the kit's default labels); `apsira_test` as a dev dependency.

- **`ApsiraThemeData.build`** adds the shared set: `highlightColor` (`tint`), the four menu
  themes (RELAY's), `snackBarTheme` (RELAY's call-site styling) and the R-10 fix.
- **R-10: light text buttons are `accentText`: goldens with a light TextButton move.** So do
  those with an `OutlinedButton`, in both themes: their label was `accentFill`, 4.39:1 on
  the light `ground`.
- **`ApsiraThemeData.buildFull`** and the builders of `ApsiraComponentThemes`: LYCEUM's
  divider, FAB, app bar, tabs, card, input decoration, chip, bottom sheet, dialog and drawer.
- **`SettingsGroup`, `SettingsRow`, `SettingsChoiceRow`, `SettingsOption`,
  `SettingsDivider`, `ApsiraMenuItem`, `ApsiraMenuButtons`** (RELAY's) and
  **`ThemeModeSetting`** with `ThemeModeStore`, `themeModeStoreProvider`,
  `initialThemeModeProvider`, `themeModeOptions` and RELAY's storage names.
- `ApsiraSchemeColors.transparent`; the `components.png` golden. `token_sheet.png` is
  unchanged.
- **The kit** (`lib/src/kit/`, exported by `apsira_ui.dart`): `CardSlice`, `CardPart`,
  `GroupHeader`, `GroupCard`, `PageTitle`, `SectionHeader`, `OverlineLabel`, `EmptyState`,
  `showApsiraSheet`/`ApsiraSheet`/`SheetHandle`, `showApsiraDialog`/`ApsiraDialog`,
  `confirmDestructive`, `confirmAction`, `destructiveButtonStyle`, `showUndoSnack`,
  `FilterPill`, `AddFilterPill`, `TagPill`, `StatusDot`, `FamilyPill`, `SearchFilterBar`,
  `ActiveFilterPills`, `PillButtons`, `IconBox`, `DrawerItem`, `DrawerHeaderBlock`. Each
  draws its surface from the tokens, under `build` as under `buildFull`.
- **`package:apsira_ui/preview.dart`**: `ThemePreviewScreen`, every token, family, type
  style, shape, spacing value and kit sample in both themes; `example/` opens it.

**Migration.** Every app moves the pin to `ref: apsira-v0.3.0`. An app that uses the kit adds
`ApsiraL10n.delegate` to its `localizationsDelegates` (its default labels).
- **RELAY:** `relay_theme.dart` calls `ApsiraThemeData.build` and drops its own menu themes
  and `highlightColor`; `RelayMenuItem`/`RelayMenuButtons` → `ApsiraMenuItem`/
  `ApsiraMenuButtons`, its settings rows → the package's (options become `SettingsOption`s),
  and `theme_mode_provider.dart` → `ThemeModeSetting` with a store on `theme_mode`. The
  call-site snack styling may go: the theme draws the same snack. Re-approve the goldens
  with a light text or outlined button (R-10). Adopting the kit: `list_widgets.dart` →
  `CardSlice`/`GroupCard`, `empty_state.dart` → `EmptyState` (its 14 empty states take
  LYCEUM's card: re-approve those goldens citing D-APK-014), the 8 undo-snack helpers →
  `showUndoSnack`, its `ThemePreview` → `ThemePreviewScreen`.
- **VIATICUM:** its snacks and its four menus take the shared look (Q4-a); re-approve those
  goldens and the R-10 ones, citing D-APK-013. Adopting the kit: `_Group`/`_Row` →
  `GroupCard`/`CardSlice`, `showUndoSnack` → the package's with `persist: false` and its
  `undoFailedMessage`; its state roles and `room` set stay its own tokens.
- **LYCEUM:** `lyceum_theme.dart` calls `ApsiraThemeData.buildFull` and keeps only its module
  colours and `actionIconTheme` on top; the copied menu and button themes go. Adopting
  the kit: `app/theme/kit/**` and the drawer parts go; `LyceumSheet`/`showLyceumSheet` →
  `ApsiraSheet`/`showApsiraSheet` (likewise the dialog), `StatusPill` → `FamilyPill`, and
  `LyceumModule`/`LyceumStatus` map once to `ApsiraFamily` (`IconBox(family:)`,
  `filled: true` for a status); the ambient module scope stays in LYCEUM.

## 0.2.0 — 2026-10-24

No change in behaviour; first release under the shared tag `apsira-v0.2.0` (D-APK-007).

**Migration.** Move the pin from `ref: apsira_ui-v0.1.0` to `ref: apsira-v0.2.0`, the same
ref as every other apsira package the app uses.

**Known issue, kept.** The light theme's `TextButton` text (`accentFill` on `ground`)
measures 4.39:1, under the 4.5:1 of Flutter's `textContrastGuideline`. 0.2.0 does not change it (no change in
behaviour); the component and menu themes of `apsira_ui` 0.3 fix it (D-APK-011).

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
