# apsira_onboarding

First open, tours, Help and tips for the Apsira apps (D-APK-017): the pieces RELAY and
VIATICUM share, on `apsira_ui`'s tokens and `apsira_l10n`'s words. Each app keeps its own
first-open screen, its tours and how-tos and their text, and its routes; it composes these
pieces.

## Consuming

Pin by the shared tag, the same ref for every apsira package (D-APK-007, `../README.md`):

```yaml
dependencies:
  apsira_onboarding: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.4.0, path: packages/apsira_onboarding } }
```

`package:apsira_onboarding/apsira_onboarding.dart` is the public surface. It depends on
`apsira_app`, `apsira_l10n`, `apsira_ui` and `flutter`, and nothing third-party. The app adds
`ApsiraL10n.delegate` to its `localizationsDelegates`; every word a widget shows comes from
there or from a parameter.

## First open

```dart
FirstOpenIntro(appTitle: l.appTitle, mark: (p) => RelayMark(progress: p), onDone: next);
LanguageStep(selected: language, onSelected: choose, onContinue: next);
final flow = FirstOpenFlow(MyStep.values);       // .current, .next(), .back(), .goTo(step)
```

- `FirstOpenIntro` draws the app's mark (`mark(progress)`, 0 to 1, in a 120 px square), its
  title as the wordmark, then "Developed by" and the Apsira Labs lockup
  (`ApsiraBrand.lockupReversed` unless `lockup` is given), on the dark ground in both themes.
  About 4.5 s; under reduce motion a 1 s cross-fade, nothing drawn or moved. A tap, or
  TalkBack's button, skips it; `onDone` is called once. `semanticsLabel` labels that button
  ("Skip the introduction"), read before the hint. Keys `firstOpen/intro[/brand|/name|/credit]`.
- `LanguageStep` offers English and Español (`options` for others); `LanguageStep.preselect`
  picks a stored choice, else the phone's (`es` → Spanish, anything else English). Keys
  `firstOpen/language/<option>` and `firstOpen/language/continue`.
- `StepFrame` is a step's frame: optional Back and Skip, the content, the primary action at
  the bottom (Continue by default); it scrolls instead of overflowing at large text. Its child
  is sized by its intrinsic height, so a `LayoutBuilder` cannot be it.
- `FirstOpenFlow<S>` is a value over the app's own step enum; what a step means is the app's.

## Tours and Help

```dart
TourPlayer(steps: steps, onDone: done, onSkip: done, keyPrefix: 'firstOpen');
HelpScreen(groups: [HelpGroup(title: l.toursHeader, children: [HelpRow(key: HelpKeys.tour('basic'), …)])]);
context.go(helpTourPath('basic'));               // '/help/tour/basic'
```

- `TourStepData` is a step as plain values: title, body, a scene builder (`progress` 0 to 1),
  the TalkBack summary and the `taps` it teaches. `TourPlayer` plays one step at a time with
  Skip (when `onSkip` is given), Back, Next and Done, the dots read as "Step n of m", and an
  optional secondary action on the last step. Each path of taps is a wrapping row, read as
  `tapPathLabel(path)` (the labels joined by commas without it). Under reduce motion every
  scene is at its end state. Keys `<keyPrefix>/skip|back|next|secondary|step/<n>|taps/<i>`.
- `HelpScreen`, `HelpGroup`, `HelpRow` (one button to TalkBack) and `HelpTourScreen` are the
  shell; `HowToPage` takes the title, the steps with their TalkBack sentence and the worked
  `HowToExample`s (typed text in JetBrains Mono, `breakable` for a condition that may wrap).
  The app's router owns `/help/tour/<id>` and `/help/howto/<id>`.

## Tips

```dart
final seen = SeenFlags(await getApplicationSupportDirectory());
if (!await seen.isSeen('quick_add')) …
OneTimeTipCard(id: 'quick_add', text: l.tipQuickAdd, onDismiss: () => seen.markSeen('quick_add'));
```

- `SeenFlags` keeps each tip or tour seen as one `InstallFlag` file, `seen/<id>.json` unless
  the app passes `pathOf`. Per install (D-APK-010 C1): a restore neither sets nor clears it. An
  id is letters, digits, `_` and `-`.
- `OneTimeTipCard` (Got it from `tipGotIt`, its `icon` the app's), `HintRotation`,
  `SuggestionChipRow` with `SuggestionChip` and `insertToken` are RELAY's discovery pieces.

## Tests

`flutter test`: RELAY's and VIATICUM's tests of the intro, the tour player, Help and
discovery, ported; the seen flags; EN/ES at 100–200 % text for every screen-sized widget
(`expectLayoutSound`); the `tour_player` golden matrix in `test/goldens/` (update with
`flutter test --update-goldens test/goldens/tour_player_golden_test.dart`).
