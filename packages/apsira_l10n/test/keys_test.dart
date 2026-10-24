// The key table of D-APK-012, asserted row by row: one expect per key and
// language, the arguments included.
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Key = (
  String name,
  String Function(ApsiraL10n l) read,
  String en,
  String es,
);

final List<_Key> _table = [
  ('commonOk', (l) => l.commonOk, 'OK', 'Aceptar'),
  ('commonCancel', (l) => l.commonCancel, 'Cancel', 'Cancelar'),
  ('commonConfirm', (l) => l.commonConfirm, 'Confirm', 'Confirmar'),
  ('commonYes', (l) => l.commonYes, 'Yes', 'Sí'),
  ('commonNo', (l) => l.commonNo, 'No', 'No'),
  ('commonSave', (l) => l.commonSave, 'Save', 'Guardar'),
  ('commonEdit', (l) => l.commonEdit, 'Edit', 'Editar'),
  ('commonDelete', (l) => l.commonDelete, 'Delete', 'Eliminar'),
  ('commonClear', (l) => l.commonClear, 'Clear', 'Borrar'),
  ('commonClearAll', (l) => l.commonClearAll, 'Clear all', 'Borrar todo'),
  ('commonUndo', (l) => l.commonUndo, 'Undo', 'Deshacer'),
  ('commonClose', (l) => l.commonClose, 'Close', 'Cerrar'),
  ('commonBack', (l) => l.commonBack, 'Back', 'Atrás'),
  ('commonNext', (l) => l.commonNext, 'Next', 'Siguiente'),
  ('commonContinue', (l) => l.commonContinue, 'Continue', 'Continuar'),
  ('commonDone', (l) => l.commonDone, 'Done', 'Listo'),
  ('commonAdd', (l) => l.commonAdd, 'Add', 'Añadir'),
  ('commonSkip', (l) => l.commonSkip, 'Skip', 'Saltar'),
  ('commonNotNow', (l) => l.commonNotNow, 'Not now', 'Ahora no'),
  ('commonDismiss', (l) => l.commonDismiss, 'Dismiss', 'Descartar'),
  ('commonSearch', (l) => l.commonSearch, 'Search', 'Buscar'),
  ('commonFilter', (l) => l.commonFilter, 'Filter', 'Filtrar'),
  ('commonRetry', (l) => l.commonRetry, 'Try again', 'Reintentar'),
  ('settingsTitle', (l) => l.settingsTitle, 'Settings', 'Ajustes'),
  ('aboutTitle', (l) => l.aboutTitle, 'About', 'Acerca de'),
  ('helpTitle', (l) => l.helpTitle, 'Help', 'Ayuda'),
  ('tipGotIt', (l) => l.tipGotIt, 'Got it', 'Entendido'),
  ('languageLabel', (l) => l.languageLabel, 'Language', 'Idioma'),
  ('languageEnglish', (l) => l.languageEnglish, 'English', 'English'),
  ('languageSpanish', (l) => l.languageSpanish, 'Español', 'Español'),
  (
    'languageFollowPhone',
    (l) => l.languageFollowPhone,
    'Follow phone',
    'Seguir el teléfono',
  ),
  (
    'firstOpenLanguageTitle',
    (l) => l.firstOpenLanguageTitle,
    'Choose your language / Elige tu idioma',
    'Choose your language / Elige tu idioma',
  ),
  ('themeLabel', (l) => l.themeLabel, 'Theme', 'Tema'),
  ('themeDark', (l) => l.themeDark, 'Dark', 'Oscuro'),
  ('themeLight', (l) => l.themeLight, 'Light', 'Claro'),
  ('themeSystem', (l) => l.themeSystem, 'Follow system', 'Seguir el sistema'),
  (
    'tourProgress(2, 5)',
    (l) => l.tourProgress(2, 5),
    'Step 2 of 5',
    'Paso 2 de 5',
  ),
  ('tourStart', (l) => l.tourStart, 'Start', 'Empezar'),
  (
    'firstOpenDevelopedBy',
    (l) => l.firstOpenDevelopedBy,
    'Developed by',
    'Desarrollado por',
  ),
  (
    'firstOpenApsiraLabs',
    (l) => l.firstOpenApsiraLabs,
    'Apsira Labs',
    'Apsira Labs',
  ),
  (
    'firstOpenIntroSkipHint',
    (l) => l.firstOpenIntroSkipHint,
    'Tap to skip',
    'Toca para saltar',
  ),
  (
    "lockPromptTitle('Relay')",
    (l) => l.lockPromptTitle('Relay'),
    'Unlock Relay',
    'Desbloquear Relay',
  ),
  (
    'lockPromptHint',
    (l) => l.lockPromptHint,
    "Confirm it's you",
    'Confirma que eres tú',
  ),
  ('lockUnlockButton', (l) => l.lockUnlockButton, 'Unlock', 'Desbloquear'),
  (
    'lockRetryMessage',
    (l) => l.lockRetryMessage,
    'Not unlocked. Try again.',
    'No se ha desbloqueado. Inténtalo de nuevo.',
  ),
  (
    'lockCoverMessage',
    (l) => l.lockCoverMessage,
    'Unlock to continue.',
    'Desbloquea para continuar.',
  ),
  (
    'lockSettingsTitle',
    (l) => l.lockSettingsTitle,
    'App lock',
    'Bloqueo de la app',
  ),
  (
    'lockSettingsSubline',
    (l) => l.lockSettingsSubline,
    'Biometrics or the screen lock',
    'Biometría o el bloqueo de pantalla',
  ),
  ('lockAfter', (l) => l.lockAfter, 'Lock after', 'Bloquear tras'),
  (
    'lockImmediately',
    (l) => l.lockImmediately,
    'Immediately',
    'Inmediatamente',
  ),
  ('lockAfterMinutes(1)', (l) => l.lockAfterMinutes(1), '1 minute', '1 minuto'),
  (
    'lockAfterMinutes(5)',
    (l) => l.lockAfterMinutes(5),
    '5 minutes',
    '5 minutos',
  ),
  (
    'lockHideInRecents',
    (l) => l.lockHideInRecents,
    'Hide in recent apps',
    'Ocultar en apps recientes',
  ),
  (
    'lockHideInRecentsSubline',
    (l) => l.lockHideInRecentsSubline,
    'Also blocks screenshots',
    'También impide hacer capturas de pantalla',
  ),
  (
    'failureUnknown',
    (l) => l.failureUnknown,
    'Something went wrong. Try again.',
    'Algo ha fallado. Inténtalo de nuevo.',
  ),
];

void main() {
  final en = ApsiraL10nEn();
  final es = ApsiraL10nEs();

  group('the D-APK-012 table', () {
    for (final (name, read, wantEn, wantEs) in _table) {
      test('$name in en and es', () {
        expect(read(en), wantEn, reason: '$name (en)');
        expect(read(es), wantEs, reason: '$name (es)');
      });
    }
  });

  test('every key is non-empty in en and es', () {
    for (final (name, read, _, _) in _table) {
      expect(read(en).trim(), isNotEmpty, reason: '$name (en)');
      expect(read(es).trim(), isNotEmpty, reason: '$name (es)');
    }
  });

  test('the table covers every key, the plural forms included', () {
    // 51 getters and three methods: 54 keys, lockAfterMinutes asserted twice.
    expect(_table.length, 54 + 1);
    expect(_table.map((k) => k.$1).toSet().length, _table.length);
  });

  test('the locales are the ones the classes declare', () {
    expect(en.localeName, 'en');
    expect(es.localeName, 'es');
  });
}
