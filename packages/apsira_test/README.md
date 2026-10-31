# apsira_test

The test support the three apps share: Android 14 font scaling, the large-text layout
check, the golden matrix with the bundled fonts, the accessibility pass, property testing
and the pump helpers. Extracted from RELAY `09b28810`, VIATICUM `78d38e0` and LYCEUM
`9f4ff27`; every `lib/src` file names its source. Each symbol keeps its source's name
except where the name named an app.

## Consuming

A `dev_dependency`, pinned by the shared tag (D-APK-007, `../README.md`):

```yaml
dev_dependencies:
  apsira_test: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.6.0, path: packages/apsira_test } }
```

`import 'package:apsira_test/apsira_test.dart';` is the whole surface. It depends on
`flutter`, `flutter_test` and `apsira_ui`, and on nothing else.

## The app around a screen

`LayoutHost` names what an app renders in: its `theme` for a brightness, its
`localizationsDelegates` and `supportedLocales`, and `forbidSideways`. The layout check,
the goldens and `pumpApsira` all take one. Its defaults are apsira_ui's themes and
Flutter's delegates, which render every language in English. A suite of real screens
passes the app's own delegates and locales, so its Spanish cases lay out Spanish.

```dart
final host = LayoutHost(
  theme: (b) => b == Brightness.dark ? MyTheme.dark : MyTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);
```

## Layout check

```dart
testWidgets('the list is sound under large text', (tester) async {
  await expectLayoutSound(tester, () => const ListScreen(), host: host);
});
```

`expectLayoutSound` builds the screen fresh for every case of `layoutCases()`. The matrix
is text scales 1.0, 1.3, 1.5 and 2.0, English and Spanish, 390 × 844 and 360 × 780, and
dark and light: 32 cases (`brightnesses:` narrows the themes). The text scaler of each case
is `AndroidFontScaler`. The test fails with one line per case and issue; `layoutIssues`
returns one case's issues. The fonts load once per test file before the first case.

Every painted `RenderParagraph` is measured word by word; each vertical scroll view is
stepped through its extent and measured at each stop. The `LayoutIssueKind`s:

- `exception`: a layout or build error during the render (`RenderFlex overflowed …`);
- `clipped`: an ellipsis or line limit, text larger than its paragraph, or text cut by an
  ancestor's clip. A scroll view clips only along its axis, and a clip around a scroll
  view is measured against what the scroll view left visible;
- `outsideBox`: text outside the nearest box that visibly draws it;
- `outsideScreen`: text outside the screen;
- `overlap`: two texts on one route overlapping by more than 1 × 2 px. A sheet over its
  route, a `Badge` over its child, and text over a scroll view that can carry its
  content clear are not overlaps;
- `squeezed`: a scroll view shorter than one line of its content;
- `sideways`: a horizontal scroll view, only when `forbidSideways` is set (VIATICUM).

`test/layout_check_test.dart` has a fixture that plants each defect and one without it.
Run it after any change to the check.

## Font scaling and fonts

`AndroidFontScaler(factor)`, or `androidFontScale(factor)`, carries Android 14's sp → dp
tables (AOSP `FontScaleConverterFactory`, API 34). At 2.0 a 14 px line becomes 26 px. It
throws for a factor without a table.

`loadBundledFonts()` loads every family in the bundle's `FontManifest.json`: apsira_ui's
and any the app adds. `loadAppFonts()` does it once per test isolate (for `setUpAll` or
`flutter_test_config.dart`); `loadBundledFontsOnce(tester)` does it inside a test.

## Goldens

```dart
goldenMatrix('home', (variant) => const HomeScreen(), host: host);
```

It registers one test per `GoldenVariant`: English and Spanish × dark and light × 100 % and
200 %. That is 8 tests, comparing against `goldens/<screen>.<locale>.<theme>.<scale>.png`
beside the test. The screen is 412 × 915 at device pixel ratio 1. The scaler is Android's
unless `scaler: TextScaler.linear` (RELAY's goldens). `themeName:` names a theme apart from
its brightness: VIATICUM maps its room theme to the light slot, named `room`. `pumpGolden`
and `goldenApp` render one variant; `withShadows` draws real elevation shadows. Update with
`flutter test --update-goldens <file>` and name the re-approval in the commit.

## Accessibility

`await expectAccessible(tester)` checks the pumped screen against
`labeledTapTargetGuideline`, `androidTapTargetGuideline` and `textContrastGuideline`.
Semantics are turned on for the call. The apps check contrast at 200 % only
(`textContrast: false` at 100 %): at 100 % the guideline samples anti-aliased strokes.

## Property testing

`forAll(gen, property)` runs a property on seeded cases. A failure is shrunk to a minimal
case and thrown with the seed that replays it. `Gens` holds the basic generators; the
domain ones (text, edits, dates, plans) stay in each app. `APSIRA_PROP_SCALE` multiplies
every run count and `APSIRA_PROP_SEED` sets the first seed.

## Pumping

`pumpApsira(tester, child, {host, brightness, theme, locale, textScale, wrapInScaffold,
surfaceSize})` pumps `child` in the host's app, scaled as Android applies `textScale`.
`testBothModes` registers a test per brightness. `unmountAndFlush` unmounts and runs the
zero-length timers a disposed screen leaves.
