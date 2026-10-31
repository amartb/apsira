# apsira_ui

The Apsira visual language as a Flutter package: the colour tokens (`ApsiraTheme`, light
and dark) and the Material `ThemeData` built from them with its component themes, the type
scale, radii, sizes and spacing, the chrome icons, the settings rows and menu items, the
theme-mode setting, the component kit, the debug ThemePreview, and the brand files every app ships: Archivo Expanded, Archivo and
JetBrains Mono, the reversed Apsira Labs lockup and their licences. Extracted from RELAY
`5f606e9` and `09b28810`, LYCEUM `9f4ff27` and VIATICUM `78d38e0` (D-APK-001, D-APK-013,
D-APK-014); every extracted file
names its source.

## Consuming

Pin by the shared tag, the same ref for every apsira package (D-APK-007, `../README.md`):

```yaml
dependencies:
  apsira_ui:
    git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.6.0, path: packages/apsira_ui }
```

`import 'package:apsira_ui/apsira_ui.dart';` is the public surface; the debug ThemePreview
is `package:apsira_ui/preview.dart`. The kit's default labels are `apsira_l10n`'s, so the
app adds `ApsiraL10n.delegate` to its `localizationsDelegates`.

## The per-app theme file

An app keeps one theme file, `lib/app/theme/<app>_theme.dart`, that composes the tokens
with its own `ThemeExtension`s; screens read tokens by name, never raw colours:

```dart
final light = ApsiraThemeData.build(ApsiraTheme.light, extensions: [MyRoles.light]);
final dark = ApsiraThemeData.build(ApsiraTheme.dark, extensions: [MyRoles.dark]);
// in a widget
final t = ApsiraTheme.of(context);       // t.surface, t.ink2, t.family(ApsiraFamily.blue)
Text('Today', style: ApsiraTypography.cardTitle.copyWith(color: t.ink));
```

Apps never construct `ApsiraTheme`; they `copyWith` from `light` or `dark`. Fonts are
declared by this package: a consumer's bundle holds them as `packages/apsira_ui/Archivo`
(`ApsiraFonts.archivoQualified`), which every style and `ThemeData.fontFamily` already
use, so the app declares no `fonts:` of its own.

## Component themes: `build` and `buildFull` (D-APK-013)

`ApsiraThemeData.build` carries the **shared set**, which every app receives: the menus
(`popupMenuTheme`, `menuTheme`, `dropdownMenuTheme`, `menuButtonTheme`: the flat bordered
`surface`, below its button), `highlightColor` (`tint`), `snackBarTheme` (`surface`,
floating, the inset-block edge, `snippet` in `ink`, the action in `accentText`), and text
and outlined buttons in `accentText` (R-10). Every other sub-theme is Material's default,
so an app's cards, dialogs, fields and app bars stay its own.

`ApsiraThemeData.buildFull` adds LYCEUM's sub-themes: divider, FAB, app bar, tabs, card,
input decoration, chip, bottom sheet, dialog and drawer. Each is also a builder on
`ApsiraComponentThemes` (`cardTheme(t)`, `dialogTheme(t)`, …) for an app that wants one.
Action icons stay the app's, since their glyphs are:

```dart
final dark = ApsiraThemeData.buildFull(ApsiraTheme.dark, extensions: [MyRoles.dark])
    .copyWith(actionIconTheme: myActionIcons);
```

## Settings rows, menu items and the theme mode

`SettingsGroup`, `SettingsRow`, `SettingsChoiceRow<T>` (with `SettingsOption(value, label)`)
and `SettingsDivider` are RELAY's Settings pieces; `ApsiraMenuItem` (icon, `danger`, the
`chosen` mark) and `ApsiraMenuButtons` (paired actions on a menu's top) are its menu rows.
Labels come from the caller: the package holds no visible string.

`themeModeProvider` (`ThemeModeSetting`) is the mode the root `MaterialApp` reads. The app
implements `ThemeModeStore` under its own key and overrides two providers:

```dart
ProviderScope(
  overrides: [
    themeModeStoreProvider.overrideWithValue(MyThemeModeStore(settings)),
    initialThemeModeProvider.overrideWithValue(themeModeFromStorage(stored)),
  ],
  child: const MyApp(),
);
```

`setMode` writes through the store; a failed write puts the previous mode back and
rethrows. Stored names are `dark`, `light` and `system`; anything else reads as dark.

## The component kit (D-APK-014)

LYCEUM's kit unless named, each file under `lib/src/kit/` naming its source. Every widget
draws its own surface (colour, shape, border, scrim) from `ApsiraTheme`, so it looks the
same under `build` and `buildFull`.

| Group | Widgets |
|---|---|
| Layout | `CardSlice`, `CardPart` (`first`, `middle`, `last`, `only`; `CardPart.at`), `GroupHeader`, `GroupCard`, `PageTitle`, `SectionHeader`, `OverlineLabel` |
| State | `EmptyState` (`actionLabel`/`onAction`/`actionKey`, the action as the tonal pill; `actionIcon` before its label; `secondaryActionLabel`/`onSecondaryAction`/`secondaryActionKey`, a second pill under it; `EmptyState.inline`, RELAY's cardless tint block with its `accentText` text button, keys `EmptyState.blockKey`/`iconTileKey`) |
| Overlays | `showApsiraSheet`, `ApsiraSheet`, `SheetHandle`, `showApsiraDialog`, `ApsiraDialog`, `confirmDestructive`, `confirmAction`, `destructiveButtonStyle` |
| Feedback | `showUndoSnack` (RELAY's; VIATICUM's failure snack, `persist`) |
| Pills | `FilterPill`, `AddFilterPill`, `TagPill`, `StatusDot`, `FamilyPill`, `SearchFilterBar`, `ActiveFilterPills`, `PillButtons` |
| Rows | `IconBox` (`family:`, `filled:`), `DrawerItem`, `DrawerHeaderBlock` |

```dart
if (await confirmDestructive(context, title: l10n.deleteNoteTitle)) delete(note);
showUndoSnack(ScaffoldMessenger.of(context),
    message: l10n.noteDeleted, onUndo: () => repo.restore(note),
    undoFailedMessage: l10n.undoFailed);
```

`confirmDestructive` resolves true on confirm and false on cancel or a barrier tap. *Undo*
calls `onUndo` once; a false result shows `undoFailedMessage` when one is given. Default
labels (cancel, delete, confirm, undo, search, filter, clear, clear all) are `ApsiraL10n`'s;
every other visible string is a parameter. `ThemePreviewScreen` shows every token, family,
type style, shape, spacing value and kit sample in both themes, keyed
`themePreview/<dark|light>/<kind>/<name>`; an app shows it in development builds only.

## The brand: `ApsiraBrand`

```dart
void main() {
  ApsiraBrand.registerLicences();   // the fonts' OFL and Lucide's ISC on the Licences page
  runApp(const MyApp());
}
const Image(image: ApsiraBrand.lockupReversed, width: 200);   // first open, About; dark grounds
```

The files under `lib/fonts/` and `lib/brand/` are copied unchanged from `apsira-brand/`
(the Archivo variable and JetBrains Mono files from google/fonts, via RELAY);
`test/brand_provenance_test.dart` checks each against its `SHA256SUMS` line and, inside
this repository, byte for byte against `../../apsira-brand/`.

## Layout and tests

| Path | Holds |
|---|---|
| `lib/src/colors.dart` | The only colour literals of any Apsira package |
| `lib/src/theme.dart` | `ApsiraTheme`, `ApsiraThemeData` (`light`, `dark`, `build`, `buildFull`, `colorScheme`) |
| `lib/src/component_themes.dart` | `ApsiraComponentThemes`: the shared set and LYCEUM's sub-themes |
| `lib/src/settings.dart`, `theme_mode.dart` | Settings rows and menu items; `ThemeModeSetting` and its store |
| `lib/src/typography.dart`, `shape.dart`, `icons.dart`, `brand.dart` | Type scale, shape, chrome glyphs, lockup and licences |
| `lib/src/kit/`, `lib/src/preview/` | The component kit; `ThemePreviewScreen` |
| `test/kit/` | The kit's ported tests, each sound at EN/ES × 100/200 % text (`expectLayoutSound`) |
| `lib/fonts/`, `lib/brand/`, `lib/licenses/` | The bundled files and their `SHA256SUMS` |
| `test/goldens/token_sheet.png` | Every token as a swatch: a value change moves it |
| `test/goldens/components.png` | The shared set, light and dark: buttons, an open menu, a snack |
| `example/` | A consumer app whose tests prove the qualified fonts, licences and lockup load and open the ThemePreview, dark and light |

`flutter analyze && flutter test` here; `cd example && rm -rf build && flutter pub get && flutter test` (a stale `build/unit_test_assets` makes the font test lie)
for the consumer proof. RELAY test groups not carried are listed in `CHANGELOG.md` 0.1.0.
