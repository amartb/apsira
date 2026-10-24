// From relay lib/app/error_handlers.dart @ 09b28810
import 'dart:ui';

import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The global error handlers: uncaught framework and platform errors go to
/// the [Log] by type and stack hash, never by message (which can carry a
/// title, a note or a path), and a release build never shows the red error
/// screen.
final class ErrorHandlers {
  ErrorHandlers._(this._flutter, this._platform, this._builder);

  /// Routes `FlutterError.onError` and `PlatformDispatcher.onError` to [log].
  ///
  /// In a release build a widget that fails to build is replaced by an empty
  /// box; in other builds the framework's error screen and console report
  /// stay, through [presentError] (by default `FlutterError.presentError`),
  /// for development.
  static ErrorHandlers install(
    Log log, {
    bool releaseMode = kReleaseMode,
    FlutterExceptionHandler? presentError,
  }) {
    final dispatcher = PlatformDispatcher.instance;
    final handlers = ErrorHandlers._(
      FlutterError.onError,
      dispatcher.onError,
      ErrorWidget.builder,
    );
    FlutterError.onError = (details) {
      log.error(
        'flutter.error',
        error: details.exception,
        stack: details.stack,
      );
      if (!releaseMode) (presentError ?? FlutterError.presentError)(details);
    };
    dispatcher.onError = (error, stack) {
      log.error('platform.uncaughtError', error: error, stack: stack);
      return true;
    };
    if (releaseMode) {
      ErrorWidget.builder = (_) => const SizedBox.shrink();
    }
    return handlers;
  }

  final FlutterExceptionHandler? _flutter;
  final ErrorCallback? _platform;
  final ErrorWidgetBuilder _builder;

  /// Puts back the handlers that were in place before [install].
  void uninstall() {
    FlutterError.onError = _flutter;
    PlatformDispatcher.instance.onError = _platform;
    ErrorWidget.builder = _builder;
  }
}
