// The shared keys of D-APK-012. Each wording comes from RELAY 09b28810,
// VIATICUM 78d38e0 or LYCEUM 9f4ff27 app_*.arb, as the decision's table names;
// hand-written, since a package ships no generated code (D-APK-001).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'apsira_l10n_en.dart';
import 'apsira_l10n_es.dart';

/// The strings the shared Apsira widgets show, in English and Spanish
/// (D-APK-012). An app adds [ApsiraL10n.delegate] beside its own delegates;
/// its own text stays in its own ARBs.
abstract class ApsiraL10n {
  /// The strings for [localeName].
  const ApsiraL10n(this.localeName);

  /// The language code these strings are in: `en` or `es`.
  final String localeName;

  /// The delegate an app adds to `MaterialApp.localizationsDelegates`.
  static const LocalizationsDelegate<ApsiraL10n> delegate =
      _ApsiraL10nDelegate();

  /// The languages written here. Any other language gets English; the app's
  /// own `supportedLocales` decide which locales it offers.
  static const supportedLocales = [Locale('en'), Locale('es')];

  /// The strings in force at [context].
  ///
  /// Throws a [FlutterError] when the app did not add [delegate]: a shared
  /// widget never falls back to English silently.
  static ApsiraL10n of(BuildContext context) {
    final l10n = Localizations.of<ApsiraL10n>(context, ApsiraL10n);
    if (l10n != null) return l10n;
    throw FlutterError.fromParts([
      ErrorSummary('No ApsiraL10n found in context.'),
      ErrorDescription(
        'A shared Apsira widget needs ApsiraL10n.delegate in the app\'s '
        'localizationsDelegates.',
      ),
      ErrorHint(
        'Add ApsiraL10n.delegate to MaterialApp.localizationsDelegates, '
        'beside the app\'s own delegates.',
      ),
    ]);
  }

  /// Acknowledges a message.
  String get commonOk;

  /// Abandons a dialog or an edit.
  String get commonCancel;

  /// Accepts a confirmation dialog.
  String get commonConfirm;

  /// "Yes".
  String get commonYes;

  /// "No".
  String get commonNo;

  /// "Save".
  String get commonSave;

  /// "Edit".
  String get commonEdit;

  /// Deletes an item (never "clear").
  String get commonDelete;

  /// Empties a field or a filter (never "delete").
  String get commonClear;

  /// "Clear all".
  String get commonClearAll;

  /// "Undo".
  String get commonUndo;

  /// "Close".
  String get commonClose;

  /// "Back".
  String get commonBack;

  /// "Next".
  String get commonNext;

  /// "Continue".
  String get commonContinue;

  /// Finishes a flow; a mark-done action stays app text.
  String get commonDone;

  /// "Add".
  String get commonAdd;

  /// "Skip".
  String get commonSkip;

  /// "Not now".
  String get commonNotNow;

  /// "Dismiss".
  String get commonDismiss;

  /// "Search".
  String get commonSearch;

  /// "Filter".
  String get commonFilter;

  /// Repeats a failed action.
  String get commonRetry;

  /// "Settings".
  String get settingsTitle;

  /// "About".
  String get aboutTitle;

  /// "Help".
  String get helpTitle;

  /// "Got it".
  String get tipGotIt;

  /// "Language".
  String get languageLabel;

  /// "English".
  String get languageEnglish;

  /// "Español".
  String get languageSpanish;

  /// "Follow phone".
  String get languageFollowPhone;

  /// The first-open language step's title, in both languages at once.
  String get firstOpenLanguageTitle;

  /// "Theme".
  String get themeLabel;

  /// "Dark".
  String get themeDark;

  /// "Light".
  String get themeLight;

  /// The theme option that follows the system.
  String get themeSystem;

  /// "Step {current} of {total}" in a tour.
  String tourProgress(int current, int total);

  /// "Start".
  String get tourStart;

  /// "Developed by".
  String get firstOpenDevelopedBy;

  /// "Apsira Labs".
  String get firstOpenApsiraLabs;

  /// "Tap to skip".
  String get firstOpenIntroSkipHint;

  /// The unlock prompt's title, naming the app.
  String lockPromptTitle(String app);

  /// "Confirm it's you".
  String get lockPromptHint;

  /// "Unlock".
  String get lockUnlockButton;

  /// Not unlocked. Try again.
  String get lockRetryMessage;

  /// Shown over the app while it is locked.
  String get lockCoverMessage;

  /// "App lock".
  String get lockSettingsTitle;

  /// "Biometrics or the screen lock".
  String get lockSettingsSubline;

  /// "Lock after".
  String get lockAfter;

  /// "Immediately".
  String get lockImmediately;

  /// A lock delay of [n] minutes ("1 minute", "5 minutes").
  String lockAfterMinutes(int n);

  /// "Hide in recent apps".
  String get lockHideInRecents;

  /// "Also blocks screenshots".
  String get lockHideInRecentsSubline;

  /// A failure with no more specific message.
  String get failureUnknown;
}

class _ApsiraL10nDelegate extends LocalizationsDelegate<ApsiraL10n> {
  const _ApsiraL10nDelegate();

  /// Every locale: a language not written here loads English, so a shared
  /// widget never finds no strings.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<ApsiraL10n> load(Locale locale) =>
      SynchronousFuture<ApsiraL10n>(switch (locale.languageCode) {
        'es' => const ApsiraL10nEs(),
        _ => const ApsiraL10nEn(),
      });

  @override
  bool shouldReload(_ApsiraL10nDelegate old) => false;
}
