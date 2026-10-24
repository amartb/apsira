// The Spanish column of D-APK-012's key table.
import 'apsira_l10n.dart';

/// The Spanish strings (D-APK-012).
class ApsiraL10nEs extends ApsiraL10n {
  /// The Spanish strings.
  const ApsiraL10nEs() : super('es');

  @override
  String get commonOk => 'Aceptar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonYes => 'Sí';

  @override
  String get commonNo => 'No';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonClear => 'Borrar';

  @override
  String get commonClearAll => 'Borrar todo';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonSkip => 'Saltar';

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get commonDismiss => 'Descartar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonFilter => 'Filtrar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get tipGotIt => 'Entendido';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFollowPhone => 'Seguir el teléfono';

  @override
  String get firstOpenLanguageTitle => 'Choose your language / Elige tu idioma';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeSystem => 'Seguir el sistema';

  @override
  String get tourStart => 'Empezar';

  @override
  String get firstOpenDevelopedBy => 'Desarrollado por';

  @override
  String get firstOpenApsiraLabs => 'Apsira Labs';

  @override
  String get firstOpenIntroSkipHint => 'Toca para saltar';

  @override
  String get lockPromptHint => 'Confirma que eres tú';

  @override
  String get lockUnlockButton => 'Desbloquear';

  @override
  String get lockRetryMessage => 'No se ha desbloqueado. Inténtalo de nuevo.';

  @override
  String get lockCoverMessage => 'Desbloquea para continuar.';

  @override
  String get lockSettingsTitle => 'Bloqueo de la app';

  @override
  String get lockSettingsSubline => 'Biometría o el bloqueo de pantalla';

  @override
  String get lockAfter => 'Bloquear tras';

  @override
  String get lockImmediately => 'Inmediatamente';

  @override
  String get lockHideInRecents => 'Ocultar en apps recientes';

  @override
  String get lockHideInRecentsSubline =>
      'También impide hacer capturas de pantalla';

  @override
  String get failureUnknown => 'Algo ha fallado. Inténtalo de nuevo.';

  @override
  String tourProgress(int current, int total) => 'Paso $current de $total';

  @override
  String lockPromptTitle(String app) => 'Desbloquear $app';

  @override
  String lockAfterMinutes(int n) => n == 1 ? '1 minuto' : '$n minutos';
}
