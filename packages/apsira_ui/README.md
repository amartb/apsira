# apsira_ui

The Apsira visual language as a Flutter package: the colour tokens (`ApsiraTheme`, light
and dark) and the Material `ThemeData` built from them, the type scale, radii, sizes and
spacing, the chrome icons, and the brand files every app ships: Archivo Expanded,
Archivo and JetBrains Mono, the reversed Apsira Labs lockup and their licences.
Extracted from RELAY `5f606e9` (D-APK-001); every extracted file names its source.

## Consuming

Pin by tag (D-APK-003, `../README.md`):

```yaml
dependencies:
  apsira_ui:
    git: { url: git@github.com:amartb/apsira.git, ref: apsira_ui-v0.1.0, path: packages/apsira_ui }
```

`import 'package:apsira_ui/apsira_ui.dart';` is the whole public surface.

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
| `lib/src/theme.dart` | `ApsiraTheme`, `ApsiraThemeData` (`light`, `dark`, `build`, `colorScheme`) |
| `lib/src/typography.dart`, `shape.dart`, `icons.dart`, `brand.dart` | Type scale, shape, chrome glyphs, lockup and licences |
| `lib/fonts/`, `lib/brand/`, `lib/licenses/` | The bundled files and their `SHA256SUMS` |
| `test/goldens/token_sheet.png` | Every token as a swatch: a value change moves it |
| `example/` | A consumer app whose test proves the qualified fonts, licences and lockup load |

`flutter analyze && flutter test` here; `cd example && rm -rf build && flutter pub get && flutter test` (a stale `build/unit_test_assets` makes the font test lie)
for the consumer proof. RELAY test groups not carried are listed in `CHANGELOG.md` 0.1.0.
