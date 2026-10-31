# apsira_onboarding changelog

One section per release, naming any migration a consumer must make. Every package shares
one tag, `apsira-vX.Y.Z` (D-APK-007).

## 0.6.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.6.0`.

## 0.5.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.5.0`.

## 0.4.0 — 2026-10-24

Migration: move every apsira `ref:` to `apsira-v0.4.0`. Additive only; no default moves.

- **`FirstOpenIntro.semanticsLabel`** (D-APK-017, F3): the tap target's label, read before
  the hint, so the intro passes the labelled-tap-target guideline; LYCEUM drops its
  `MergeSemantics` wrapper.

## 0.3.0 — 2026-10-24

First release (D-APK-017): `FirstOpenIntro`, `LanguageStep` and `LanguageOption`,
`StepFrame`, `FirstOpenFlow<S>`, `TourStepData` and `TourPlayer`, the Help shell
(`HelpScreen`, `HelpGroup`, `HelpRow`, `HelpTourScreen`, `HowToPage`, `HowToExampleRow`,
`helpTourPath`), the discovery pieces (`OneTimeTipCard`, `HintRotation`, `SuggestionChipRow`,
`insertToken`) and `SeenFlags`. From RELAY `09b28810`, VIATICUM `78d38e0` and LYCEUM
`9f4ff27`. Dependencies `apsira_app`, `apsira_l10n`, `apsira_ui` and `flutter`.

**Migration for every app.** Add `ApsiraL10n.delegate` (apsira_l10n). Replace the app's
intro, tour player, tour step, Help rows and groups with these, passing its mark, title and
words; keep its first-open screen, tours, how-tos and routes. Each change below is a line in
the app's decision log.

- **RELAY:** the intro's timeline is 4.5 s (was 5 s) and its lockup is
  `ApsiraBrand.lockupReversed` by default. One-time tips move from the `tips_dismissed`
  setting to `SeenFlags` (per install, D-APK-010 C1): write each stored id once with
  `markSeen` at adoption, pass `pathOf` for the layout R1 chose, and pass the Lucide bulb as
  `OneTimeTipCard.icon`. `FirstOpenFlow` becomes the app's own state over
  `FirstOpenFlow<FirstOpenStep>` (the tour step, the language and Show me more stay the app's).
  Help's app bar wraps a title too long for one line and grows to hold it, where RELAY's
  `tour_screen` cut "Recordatorios y repeticiones" with an ellipsis at large text; a title
  that fits keeps the standard bar.
- **VIATICUM:** the tour's words come from `ApsiraL10n` (Skip "Saltar", Done "Listo",
  "Step n of m"), its dots take `accentText` and its buttons RELAY's styles; pass
  `tapPathLabel: (p) => l.tourTapPath(p.join(', ${l.tourTapThen} '))`. `FirstOpenKeys`
  becomes `FirstOpenIntro`'s keys and the `firstOpen/` prefixes, which are unchanged.
- **LYCEUM:** `OnboardingFrame` may become `StepFrame` (its footer is the primary action);
  adoption decides, with its tour carousel.
