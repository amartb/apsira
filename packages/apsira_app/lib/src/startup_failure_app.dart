// From lyceum lib/app/bootstrap.dart `StartupFailureApp` @ 9f4ff27 (with
// its ErrorState, lib/app/theme/kit/state/error_state.dart), with every
// string and the theme the app's.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

/// The minimal fatal screen an app shows instead of itself when its start
/// fails before `runApp` (the database cannot be opened or checked): an
/// icon and the app's message, dark whatever the platform brightness. The
/// failure is logged by the app, by type, never by message.
///
/// The strings are read through the app's [localizationsDelegates], so the
/// screen follows the phone's language: [title] and [message] are given the
/// screen's context (`(context) => AppLocalizations.of(context).appName`).
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.title,
    required this.message,
    this.theme,
    this.localizationsDelegates = const [],
    this.supportedLocales = const [Locale('en')],
    this.icon = ApsiraIcons.failed,
  });

  /// The task switcher's title: the app's name.
  final String Function(BuildContext context) title;

  /// What the screen says.
  final String Function(BuildContext context) message;

  /// The app's dark theme; `ApsiraThemeData.dark` when null.
  final ThemeData? theme;

  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;
  final Iterable<Locale> supportedLocales;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = theme ?? ApsiraThemeData.dark;
    return MaterialApp(
      onGenerateTitle: title,
      debugShowCheckedModeBanner: false,
      theme: dark,
      darkTheme: dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      home: _StartupFailureScreen(message: message, icon: icon),
    );
  }
}

class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({required this.message, required this.icon});

  final String Function(BuildContext context) message;
  final IconData icon;

  /// The error state's hero icon and its gaps (LYCEUM's ErrorState).
  static const _iconSize = 64.0;
  static const _gap = 16.0;
  static const _padding = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: _iconSize, color: theme.colorScheme.error),
                const SizedBox(height: _gap),
                Text(
                  message(context),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ApsiraTheme.of(context).ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
