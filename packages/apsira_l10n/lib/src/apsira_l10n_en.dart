// The English column of D-APK-012's key table.
import 'apsira_l10n.dart';

/// The English strings (D-APK-012).
class ApsiraL10nEn extends ApsiraL10n {
  /// The English strings.
  const ApsiraL10nEn() : super('en');

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonSave => 'Save';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonClearAll => 'Clear all';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDone => 'Done';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonRetry => 'Try again';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get aboutTitle => 'About';

  @override
  String get helpTitle => 'Help';

  @override
  String get tipGotIt => 'Got it';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFollowPhone => 'Follow phone';

  @override
  String get firstOpenLanguageTitle => 'Choose your language / Elige tu idioma';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get tourStart => 'Start';

  @override
  String get firstOpenDevelopedBy => 'Developed by';

  @override
  String get firstOpenApsiraLabs => 'Apsira Labs';

  @override
  String get firstOpenIntroSkipHint => 'Tap to skip';

  @override
  String get lockPromptHint => "Confirm it's you";

  @override
  String get lockUnlockButton => 'Unlock';

  @override
  String get lockRetryMessage => 'Not unlocked. Try again.';

  @override
  String get lockCoverMessage => 'Unlock to continue.';

  @override
  String get lockSettingsTitle => 'App lock';

  @override
  String get lockSettingsSubline => 'Biometrics or the screen lock';

  @override
  String get lockAfter => 'Lock after';

  @override
  String get lockImmediately => 'Immediately';

  @override
  String get lockHideInRecents => 'Hide in recent apps';

  @override
  String get lockHideInRecentsSubline => 'Also blocks screenshots';

  @override
  String get failureUnknown => 'Something went wrong. Try again.';

  @override
  String tourProgress(int current, int total) => 'Step $current of $total';

  @override
  String lockPromptTitle(String app) => 'Unlock $app';

  @override
  String lockAfterMinutes(int n) => n == 1 ? '1 minute' : '$n minutes';
}
